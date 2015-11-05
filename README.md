# fluent-plugin-pull_forward_insecure

[Fluentd](http://fluentd.org) input/output plugin to forward data, by pulling/request-based transportation, over HTTP.

We can do with pull_forward:
* transfer data into hosts in firewall by pulling
* fetch Fluentd events as JSON by HTTP from any processes

![plugin image](https://raw.githubusercontent.com/tagomoris/fluent-plugin-pull_forward/master/misc/plugin_image.png)

## Configuration

### PullForwardOutput

Configure output plugin to transfer fluentd events to another fluentd nodes.

```apache
<match dummy>
  type pull_forward_insecure
  
  bind 0.0.0.0 ## default
  port 24280   ## default
  
  buffer_path    /home/myname/tmp/fluentd_event.buffer
  flush_interval 1m   ## default 1h
  
  self_hostname      ${hostname}
</match>
```

PullForwardOutput uses PullPoolBuffer plugin. **DO NOT MODIFY buffer_type**. It uses buffer file, so `buffer_path` is required, and Not so short values are welcome for `flush_interval` because PullPoolBuffer make a file per flushes (and these are not removed until fetches of cluent/in\_pull\_forward).

### PullForwardInput

Configure input plugin to fetch fluentd events from another fluentd nodes.

```apache
<source>
  type pull_forward_insecure
  
  fetch_interval 10s
  timeout 10s
</source>
```

PullForwardInput can fetch events from many nodes of `<server>`.

### HTTP fetch

We can fluentd events from PullForwardOutput by normal HTTP.

```
$ curl http://localhost:24280/
[
  [ "test.foo", 1406915165, { "pos": 8, "hoge": 1 } ],
  [ "test.foo", 1406915168, { "pos": 9, "hoge": 1 } ],
  [ "test.foo", 1406915173, { "pos": 0, "hoge": 0 } ]
]
```

## TODO

* TESTS!

## Copyright

* Copyright (c) 2015- Yuri odagiri (ixixi)
* License
  * Apache License, Version 2.0
