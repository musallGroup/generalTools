screens = Screen('Screens');
for i = screens
    [win, rect] = Screen('OpenWindow', i, [128 128 128]);
    DrawFormattedText(win, sprintf('Screen %d', i), 'center', 'center', [255 255 255]);
    Screen('Flip', win);
    WaitSecs(2);
    Screen('Close', win);
end