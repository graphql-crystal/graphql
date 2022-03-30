# Benchmark

Simple benchmark, comparable to https://github.com/appleboy/golang-graphql-benchmark

To reproduce:

1. Launch server with CRYSTAL_WORKERS being equal threads: `CRYSTAL_WORKERS=8 crystal run --release -D preview_mt main.cr`
2. `wrk -t12 -c400 -d30s --timeout 10s --script=post.lua --latency http://127.0.0.1:3000/graphql`

Sample result (Ryzen 2400g):

```
Running 30s test @ http://127.0.0.1:3000/graphql
  12 threads and 400 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     5.11ms    6.12ms 244.40ms   90.16%
    Req/Sec     7.49k     1.21k   16.15k    81.80%
  Latency Distribution
     50%    3.88ms
     75%    6.70ms
     90%   11.17ms
     99%   18.25ms
  2674923 requests in 30.03s, 426.02MB read
Requests/sec:  89078.22
Transfer/sec:     14.19MB
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
