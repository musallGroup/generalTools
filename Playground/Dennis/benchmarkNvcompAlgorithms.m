function csvPath = benchmarkNvcompAlgorithms(localSrc, serverDst, varargin)
    % Benchmark multiple nvCOMP algorithms against one real, server-hosted
    % file, to see which suits your situation best (ratio, speed, and - for
    % one reference algorithm - real measured network write/read-back time).
    %
    % Stages a copy of localSrc to serverDst first if it doesn't already
    % exist there (dual-checksum verified, fails closed - see nvcompTIF.py's
    % stage()), then runs the benchmark against that staged copy. The staged
    % source file persists across repeated runs so you don't re-pay the
    % network read every time you tweak the algorithm list; only the
    % reference algorithm's temporary round-trip archive is cleaned up after
    % each run (pass 'keepStaged', true to keep it instead).
    %
    % Reads the source once and reuses it (as host bytes) across every
    % algorithm's encode() - no repeated network reads. Each algorithm uses
    % its own safe chunk size (RAW bitstream mode's limits vary hugely by
    % algorithm - see nvcompTIF.py's module docstring), so absolute numbers
    % reflect what compress() would really do for that algorithm. Only ONE
    % real network write + read-back happens, for a reference algorithm
    % (default 'Zstd', matching this toolset's production default) -
    % everything else's network-inclusive time is an ESTIMATE derived from
    % that one measured MB/s figure applied to each algorithm's own real
    % compressed size, clearly labeled as such in the printed table and CSV.
    %
    % Inputs:
    % - localSrc: local file to benchmark with (e.g. a real ScanImage TIF)
    % - serverDst: destination path for the staged copy (e.g. an SMB-mounted
    %   path under your own Team/<Name> folder - pick somewhere that won't
    %   collide with real project data)
    % - algorithms: cell array of algorithm names, default: all of
    %   {'LZ4','Snappy','Zstd','Deflate','GDeflate','ANS','Bitcomp','Gzip','Cascaded'}
    % - networkRefAlgorithm: which algorithm gets the one real network
    %   round trip (default 'Zstd')
    % - pythonPath: python executable with nvcomp installed (default 'python')
    % - keepStaged: keep the reference round-trip archive after benchmarking
    %   (default false - only the staged SOURCE copy persists either way)
    % - force: re-stage even if serverDst already exists (default false)
    %
    % Output:
    % - csvPath: path to the timestamped CSV written under
    %   Playground/Dennis/benchmark_results/ (empty if the run failed)
    %
    % Usage:
    %   benchmarkNvcompAlgorithms('/local/path/to/big.tif', ...
    %       '/mnt/server/Team/Dennis/nvcomp_benchmark_scratch/big.tif')
    %   benchmarkNvcompAlgorithms(src, dst, 'algorithms', {'Zstd','LZ4','Bitcomp'})
    %   benchmarkNvcompAlgorithms(src, dst, 'pythonPath', '/home/user/nvcomp-env/bin/python')

    p = inputParser;
    addRequired(p, 'localSrc');
    addRequired(p, 'serverDst');
    addParameter(p, 'algorithms', {});
    addParameter(p, 'networkRefAlgorithm', 'Zstd');
    addParameter(p, 'pythonPath', 'python');
    addParameter(p, 'keepStaged', false);
    addParameter(p, 'force', false);
    parse(p, localSrc, serverDst, varargin{:});

    algorithms         = p.Results.algorithms;
    networkRefAlgorithm = p.Results.networkRefAlgorithm;
    pythonPath          = p.Results.pythonPath;
    keepStaged          = p.Results.keepStaged;
    force               = p.Results.force;

    funcPath = fileparts(which(mfilename));
    scriptPath = fullfile(funcPath, 'nvcompTIF.py');

    if force || exist(serverDst, 'file') ~= 2
        fprintf('Staging %s -> %s ...\n', localSrc, serverDst);
        stageCmd = sprintf('%s "%s" stage "%s" "%s"', pythonPath, scriptPath, localSrc, serverDst);
        [status, result] = system(stageCmd, '-echo');
        if status ~= 0 || ~contains(result, 'STAGE_OK')
            error('Staging failed:\n%s', result);
        end
    else
        fprintf('Using already-staged copy at %s (pass ''force'', true to re-stage)\n', serverDst);
    end

    resultsDir = fullfile(funcPath, 'benchmark_results');
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end
    csvPath = fullfile(resultsDir, sprintf('nvcomp_benchmark_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'))); %#ok<TNOW1,DATST>

    networkOut = [serverDst '.benchmark_ref.nvcz'];

    benchCmd = sprintf('%s "%s" benchmark "%s" --network-ref-algorithm %s --network-out "%s" --csv "%s"', ...
        pythonPath, scriptPath, serverDst, networkRefAlgorithm, networkOut, csvPath);
    if ~isempty(algorithms)
        benchCmd = sprintf('%s --algorithms %s', benchCmd, strjoin(algorithms, ','));
    end
    if keepStaged
        benchCmd = sprintf('%s --keep-staged', benchCmd);
    end

    fprintf('\nRunning benchmark (this involves one real network write+read-back for %s)...\n', networkRefAlgorithm);
    [status, result] = system(benchCmd, '-echo');

    if status ~= 0 || ~contains(result, 'BENCHMARK_OK')
        error('Benchmark failed:\n%s', result);
    end

    if ~exist(csvPath, 'file')
        csvPath = '';
    end
end
