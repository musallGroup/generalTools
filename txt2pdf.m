function txt2pdf(inputTxtFile, outputPdfFile, linesPerPage, fontSize)
%TXT2PDF Convert .txt to multi-page A4 PDF (works on older MATLAB versions)
%
%   txt2pdf('input.txt')
%   txt2pdf('input.txt','out.pdf')
%   txt2pdf('input.txt',[],55,10)

    % ---------------- Defaults ----------------
    if nargin < 2 || isempty(outputPdfFile)
        [p,n] = fileparts(inputTxtFile);
        outputPdfFile = fullfile(p, [n '.pdf']);
    end
    if nargin < 3 || isempty(linesPerPage), linesPerPage = 60; end
    if nargin < 4 || isempty(fontSize),     fontSize = 10;    end

    % intermediate PostScript file
    psFile = [tempname '.ps'];

    % delete old output if exists
    if isfile(psFile), delete(psFile); end
    if isfile(outputPdfFile), delete(outputPdfFile); end

    % ---------------- Read input ----------------
    raw = fileread(inputTxtFile);
    lines = regexp(raw, '\r\n|\n|\r', 'split');
    if isempty(lines{end}), lines(end) = []; end

    % ---------------- Page loop ----------------
    n = numel(lines);
    firstPage = true;

    for startIdx = 1:linesPerPage:n
        endIdx = min(startIdx + linesPerPage - 1, n);
        pageText = strjoin(lines(startIdx:endIdx), newline);

        % A4 figure
        fig = figure('Visible','off', ...
            'PaperUnits','centimeters', ...
            'PaperSize',[21 29.7], ...
            'PaperPosition',[0 0 21 29.7]);

        annotation('textbox',[0.06 0.06 0.88 0.88], ...
            'String',pageText, ...
            'Interpreter','none', ...
            'FontName','Courier', ...
            'FontSize',fontSize, ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','top', ...
            'EdgeColor','none');

        if firstPage
            print(fig, psFile, '-dpsc');
            firstPage = false;
        else
            print(fig, psFile, '-dpsc', '-append');
        end

        close(fig);
    end

    % ---------------- Convert PS → PDF ----------------
    % Ghostscript command (auto-detect platform)
    if ispc, gsCmd = 'gswin64c'; else, gsCmd = 'gs'; end

    cmd = sprintf('%s -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile="%s" "%s"', ...
        gsCmd, outputPdfFile, psFile);

    status = system(cmd);
    if status ~= 0
        error('Ghostscript conversion failed. Make sure GS is installed and in PATH.');
    end

    delete(psFile);
    fprintf('Created multi-page A4 PDF: %s\n', outputPdfFile);
end
