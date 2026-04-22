vcl 4.1;

import std;

# backend: the h3t plumber service in the shared docker network
backend default {
    .host = "h3t_api";
    .port = "8889";
    .connect_timeout = 5s;
    .first_byte_timeout = 10s;
    .between_bytes_timeout = 5s;
}

# ACL for cache-invalidation (only from within the docker network)
acl purgers {
    "localhost";
    "127.0.0.1";
    "172.16.0.0"/12;  # docker default bridge networks
    "10.0.0.0"/8;
}

sub vcl_recv {
    # support PURGE (single-object) and BAN (regex) from internal addresses
    if (req.method == "PURGE") {
        if (!client.ip ~ purgers) { return (synth(403, "PURGE not allowed")); }
        return (purge);
    }
    if (req.method == "BAN") {
        if (!client.ip ~ purgers) { return (synth(403, "BAN not allowed")); }
        ban("obj.http.X-Url ~ " + req.url);
        return (synth(200, "banned"));
    }

    # only cache GETs under /h3t/
    if (req.method != "GET" && req.method != "HEAD") { return (pass); }
    if (req.url !~ "^/h3t/") { return (pass); }

    # caddy gzips at the edge and the plumber backend never compresses, so
    # the cached object is always a single uncompressed variant. strip
    # Accept-Encoding before the hash lookup so a stray header from the
    # upstream edge can't fragment the cache into per-encoding copies.
    unset req.http.Accept-Encoding;

    # healthcheck + meta: cache briefly, not worth a cache object
    if (req.url ~ "^/h3t/health$" || req.url ~ "^/h3t/meta$") {
        return (pass);
    }

    return (hash);
}

sub vcl_backend_response {
    # stash the URL so BAN can match against it later
    set beresp.http.X-Url = bereq.url;

    # default: 24h TTL + 1h grace for tile endpoints. if the client did not
    # include a release param, fall back to a short TTL (10min) so a bad
    # deploy can't stick in the cache.
    if (bereq.url ~ "^/h3t/.+\.h3t" || bereq.url ~ "^/h3t/stats") {
        if (bereq.url ~ "[?&]release=") {
            set beresp.ttl = 24h;
            set beresp.grace = 1h;
        } else {
            set beresp.ttl = 10m;
            set beresp.grace = 1m;
        }
    }

    # do not cache any non-2xx response
    if (beresp.status != 200) {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
    }
}

sub vcl_deliver {
    # observability: let clients/dashboards see hit vs miss
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    unset resp.http.X-Url;
}
