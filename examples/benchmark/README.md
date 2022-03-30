# Benchmark

Simple benchmark, comparable to https://github.com/appleboy/golang-graphql-benchmark

To reproduce:

1. Launch server with CRYSTAL_WORKERS being equal threads: `CRYSTAL_WORKERS=8 crystal run -D preview_mt main.cr`
2. `wrk -t12 -c400 -d30s --timeout 10s --script=post.lua --latency http://127.0.0.1:3000/graphql`

Sample result (Ryzen 2400g):

```
Running 30s test @ http://localhost:3000/graphql
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    11.97ms   12.34ms 260.29ms   89.31%
    Req/Sec     3.23k   722.55     8.26k    72.77%
  Latency Distribution
     50%    9.35ms
     75%   15.94ms
     90%   25.01ms
     99%   52.00ms
  1150462 requests in 30.04s, 206.27MB read
Requests/sec:  38303.88
Transfer/sec:      6.87MB
```

For comparison, the result from gin + gqlgen (the fastest implementation in Go):

```
Running 30s test @ http://localhost:8080/graphql
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     9.82ms   13.23ms 170.52ms   85.62%
    Req/Sec     6.81k     1.38k   12.16k    67.67%
  Latency Distribution
     50%    4.12ms
     75%   15.06ms
     90%   27.79ms
     99%   57.29ms
  2443735 requests in 30.06s, 312.29MB read
Requests/sec:  81298.89
Transfer/sec:     10.39MB
```

Note: No optimization work has been done on graphql-crystal so far,
it's possible we may be able to catch up to or even surpass gqlgen.