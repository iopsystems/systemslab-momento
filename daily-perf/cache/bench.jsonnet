local systemslab = import 'systemslab.libsonnet';
local client_config = {
    general: {
        protocol: 'momento',
        interval: 1,
        duration: error 'duration must be specified',
        metrics_output: 'output.parquet',
        metrics_format: 'parquet',
        admin: '127.0.0.1:4444',
        initial_seed: '0',
    },
    debug: {
        log_level: 'info',
        log_backup: 'rpc-perf.log.old',
        log_max_size: 1073741824,
    },
    target: {
        endpoints: [],
        cache_name: 'load-test-cache',
    },
    client: {
        connect_timeout: 1000,
        request_timeout: 1000,
        threads: error 'threads must be specified',
        poolsize: error 'poolsize must be specified',
        concurrency: error 'concurrency must be specified',
    },
    workload: {
        threads: 1,
        ratelimit: error 'a ratelimit config must be specified',
        keyspace: error 'keyspace must be specified',
    },
};

function(duration='300', threads='4', poolsize='43', concurrency='20', nkeys='10000', klen='100', vlen='4000', rw_ratio='1')
    local args = {
        duration: duration,
        threads: threads,
        poolsize: poolsize,
        concurrency: concurrency,
        nkeys: nkeys,
        klen: klen,
        vlen: vlen,
        rw_ratio: rw_ratio,
    };
    local
        duration = std.parseInt(args.duration),
        threads = std.parseInt(args.threads),
        poolsize = std.parseInt(args.poolsize),
        concurrency = std.parseInt(args.concurrency),
        nkeys = std.parseInt(args.nkeys),
        klen = std.parseInt(args.klen),
        vlen = std.parseInt(args.vlen),
        rw_ratio = std.parseJson(args.rw_ratio),

        weights = if rw_ratio >= 1 then
            [std.round(10 * rw_ratio), 10]
        else
            [10, std.round(10 / rw_ratio)],
        read_weight = weights[0],
        write_weight = weights[1];

    assert std.isNumber(rw_ratio) : 'rw_ratio must be a number';

    local
        keyspace = {
            weight: 1,
            klen: klen,
            nkeys: nkeys,
            vkind: 'bytes',
            vlen: vlen,
            commands: [
                { verb: 'get', weight: read_weight },
                { verb: 'set', weight: write_weight },
            ],
        },
        ratelimit_config = {
            start: 5000,
            end: 65000,
            step: 2500,
            interval: 240,
        },
        loadgen_config = client_config {
            general+: {
                duration: duration,
            },
            client+: {
                threads: threads,
                poolsize: poolsize,
                concurrency: concurrency,
            },
            workload+: {
                ratelimit: ratelimit_config,
                keyspace: [keyspace],
            },
        };

    {
        name: 'daily-perf_cache',
        jobs: {
            client: {
                local loadgen = std.manifestTomlEx(loadgen_config, ''),

                host: {
                    tags: ['client'],
                },

                steps: [
                    // Write out the toml config
                    systemslab.write_file('loadgen.toml', loadgen),

                    // Wait for the backend and frontend dummy jobs to start
                    systemslab.barrier('test-start'),

                    // Now run the real benchmark
                    systemslab.bash(|||
                        set -a && source /etc/environment && set +a
                        rpc-perf loadgen.toml
                    |||),

                    // Indicate completion
                    systemslab.barrier('test-finish'),

                    // Upload the artifacts
                    systemslab.upload_artifact('output.parquet'),
                ],
            },

            # NOTE: to collect Rezolus telemetry from router and storage nodes
            #   we can use these simple jobs which do nothing but wait for the
            #   rpc-perf run to complete

            router: {
                 host: {
                     tags: ['router'],
                 },
                 steps: [
                     // Wait for the test to finish
                     systemslab.barrier('test-finish'),
                 ],
            },
            # storage: {
            #     host: {
            #         tags: ['storage'],
            #     },
            #     steps: [
            #         // Wait for the test to finish
            #         systemslab.barrier('test-finish'),
            #     ],
            # },
        },
    }
