function nhline(x,varargin)

a = gca;
if ishold(a)
    checker = true;
else
    hold(a,'on'); checker = false;
end

for xx = 1 : length(x)
    plot(a.XLim,[x(xx),x(xx)],varargin{:});
end