# Go

- Go Code Review Comments に従う。
  - doc コメントは完全な文にする。
  - エラー文字列は小文字で始める。
- 「見つからない」ことを `nil, nil` で表さない。`fs.ErrNotExist` またはそのドメインのセンチネルエラーを返すか、ラップする。
- チャネルに書き込む goroutine は、リークしないよう `context.Context` のキャンセルを尊重する。
- map の反復順はランダムなので、出力を作る前にソートする。
- map へのポインタを取らない。
