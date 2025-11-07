# nadeko.net Invidious fork

これは、私が自分のインスタンスのために行った機能を備えたInvidiousのフォークです。インスタンスを維持したい場合は、このフォークとそのコンテナイメージを自由に使用してください（ドッカーだけでなく、Podmanとも互換性があります！）(色々と日本語訳中)

https://git.nadeko.net/Fijxu/-/packages/container/invidious/latest

> [!CAUTION]
> アップストリームコードを実行しているInvidiousインスタンスがすでにある場合、このフォークに移動しても機能しません。
> これは、データベースの移行を必要とする「PostgreSQL上のマテリアライズドビューの除去」プルリクエストによるものです。
> using it.
>
> まだインスタンスをお持ちでない場合は、このフォークを安全に使用できますが、上流のInvidiousに切り替えることはできません。

## このフォークの特徴と変更点：

- [ビデオキャッシュには、PostgreSQLだけでなく、Redis互換のDBを使用してください。](https://git.nadeko.net/Fijxu/invidious/commit/bbc5913b8dacaed4d466bcc466a0782d5e3f5edc): InvidiousはデフォルトでPostgreSQLで数時間ビデオ情報をキャッシュします。データへのアクセスが多いため、代わりにインメモリデータベースを使用する方が良いです。高速で、SSDを消耗しません（データベースへの書き込みが常にあるため）。

これを使って設定できます `config.yml`:
```yaml
redis_url: tcp://127.0.0.1:6379
```

- [Removal of materialized views on PostgreSQL](github.com/iv-org/invidious/pull/2469): Invidiousのパブリックインスタンスにこれがない場合、SSDは問題が発生し、発火します https://github.com/iv-org/invidious/pull/2469#issuecomment-2012623454

- 外部ビデオ再生プロキシ：Invidiousにバンドルされているプロキシの代わりに、https://git.nadeko.net/Fijxu/http3-ytproxyまたはhttps://github.com/TeamPiped/piped-proxyなどの外部ビデオ再生プロキシを使用します。ビデオをプロキシしていて、スループットが低くない場合に便利です。異なるサーバーにトラフィックを分散するためにこれを行いました。少数の人だけにセルフホスティングしている場合、これはあなたにとって本当に役に立ちません。

It can be set using this on `config.yml`:
```yaml
external_videoplayback_proxy: "https://inv-proxy.example.com"
```

> [!NOTE]
> これを設定すると、Invidiousは`https://inv-proxy.example.com/health`へのリクエストを行うプロキシが生きているかどうかをチェックし、200の応答コードを取得しない場合、Invidiousはローカルビデオ再生プロキシにフォールバックします！これは現在、https://git.nadeko.net/Fijxu/http3-ytproxyでのみサポートされています。

- Limit the DASH resolution sent to the clients: It can be set using `max_dash_resolution` on the config. Example: `max_dash_resolution: 1080`

- [Limit requests made to Youtube API when pulling subscriptions (feeds)](https://git.nadeko.net/Fijxu/invidious/commit/df94f1c0b82d95846574487231ea251530838ef0): Due to the recent changes of Youtube ("これはコミュニティを保護するのに役立ちます」、「あなたがボットではないことを確認するためにサインインしてください"), サブスクリプションは現在、情報が限られています。これは、Invidiousがデフォルトで、ビデオに関する詳細情報を取得できるように、YouTubeにビデオリクエストを行うためです。 `length_seconds`, `live_now`, `premiere_timestamp`, and `views`. 大量のサブスクリプションを持つユーザーがたくさんいる場合、Invidiousは基本的に常にyoutube APIをスパムし、その結果、youtubeからブロックされます。

It can be set using this on `config.yml`:
```yaml
use_innertube_for_feeds: false
```

---

このフォークに追加したものはもっとありますが、それらは最も重要なものです。また、https://github.com/iv-org/invidiousからのマージされていないプルリクエストとランダムな修正を定期的にマージします。最も安定したコードベースではありませんが、YouTubeがそこにあるすべてのサードパーティのクライアントを破壊しようとしているとき、あなたは本当に安定したものを作ることはできません。
