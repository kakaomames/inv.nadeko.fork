module BackendInfo
  extend self
  @@exvpp_url : Array(String) = Array.new(CONFIG.invidious_companion.size, "")
  @@status : Array(Int32) = Array.new(CONFIG.invidious_companion.size, 0)
  @@csp : Array(String) = Array.new(CONFIG.invidious_companion.size, "")
  @@working_ends : Array(Int32) = Array(Int32).new(0)
  @@mutex : Mutex = Mutex.new
  @@working_mutex : Mutex = Mutex.new

  def check_backends
    check_companion()
    LOGGER.debug("Invidious companion: Updating working_ends")
    updated_ends = Array(Int32).new(0)
    @@status.each_with_index do |_, index|
      if @@status[index] == 2
          updated_ends.push(index)
      end
    end
    @@working_mutex.synchronize do
      @@working_ends = updated_ends
    end
    LOGGER.debug("Invidious companion: New working_ends \"#{@@working_ends}\"")
  end

  private def check_companion
    # Create Channels the size of CONFIG.invidious_companion
    comp_size = CONFIG.invidious_companion.size
    channels = Channel(Nil).new(comp_size)
    LOGGER.debug("Invidious companion: comp_size \"#{comp_size}\"")
    CONFIG.invidious_companion.each_with_index do |companion, index|
      spawn do
        begin
          client = HTTP::Client.new(companion.private_url)
          client.connect_timeout = 10.seconds
          response = client.get("/healthz")
          if response.status_code == 200
            check_videoplayback_proxy(companion, index)
            generate_csp([companion.public_url.to_s, companion.i2p_public_url.to_s], @@exvpp_url[index], index)
          else
            @@mutex.synchronize do
              @@status[index] = 0
            end
          end
        rescue
          @@mutex.synchronize do
            @@status[index] = 0
          end
        ensure
          LOGGER.debug("Invidious companion: Done Index: \"#{index}\"")
          channels.send(nil)
        end
      end
    end
    # Wait until we receive a signal from them all
    comp_size.times { channels.receive }
  end

  private def check_videoplayback_proxy(companion : Config::CompanionConfig, index : Int32)
    begin
      info = HTTP::Client.get "#{companion.private_url}/info"
      exvpp_url = JSON.parse(info.body)["external_videoplayback_proxy"]?.try &.to_s
    rescue JSON::ParseException
      @@mutex.synchronize do
        @@status[index] = 2
      end
      return
    end

    exvpp_url = "" if exvpp_url.nil?
    @@exvpp_url[index] = exvpp_url
    if exvpp_url.empty?
      @@mutex.synchronize do
        @@status[index] = 2
      end
      return
    else
      begin
        exvpp_health = HTTP::Client.get "#{exvpp_url}/health"
        if exvpp_health.status_code == 200
          @@mutex.synchronize do
            @@status[index] = 2
          end
          return exvpp_url
        else
          @@mutex.synchronize do
            @@status[index] = 1
          end
        end
      rescue
        @@mutex.synchronize do
          @@status[index] = 1
        end
      end
    end
  end

  private def generate_csp(companion_url : Array(String), exvpp_url : String? = nil, index : Int32? = nil)
    @@mutex.synchronize do
      @@csp[index] = ""
      companion_url.each do |url|
        @@csp[index] += " #{url}"
      end
      @@csp[index] += " #{exvpp_url}"
    end
  end

  def get_status
    return @@status
  end

  def get_working_ends
    # We need to stall this if we are updating the array
    # Not doing this can cause this to return weird values while being updated
    @@working_mutex.synchronize do
      @@working_ends.dup
    end
  end

  def get_exvpp
    return @@exvpp_url
  end

  def get_csp(index : Int32)
    # A little mutex to prevent sending a partial CSP header
    # Not sure if this is necessary. But if the @@csp[index] is being assigned
    # at the same time when it's being accessed, a data race will appear
    @@mutex.synchronize do
      return @@csp[index], @@csp[index]
    end
  end
end
