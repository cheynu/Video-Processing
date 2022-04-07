function out = DSRT_DataMerge_Block(btAll,idx_method)

switch nargin
    case 1
        idx_method = 3;
    otherwise
        %pass;
end

methodlist = {'raw','merge','select'};
method = methodlist{idx_method};

date = [];
for i=1:length(btAll)
    date(i) = btAll{i}.Date(1);
end
if length(unique(date))==length(btAll)
    out = btAll;
    return;
end
pAll = {};
out = {};o = 1;
rec = [];
for i=1:length(date)
    tdate = date;
    tdate(i) = [];
    if ismember(date(i),tdate)
        pending = find(date==date(i));
        date(pending) = NaN;
        pAll{end+1} = pending;
        out{o} = {};
        rec = [rec,o];
        o = o + 1;
    else
        if ~isnan(date(i))
            out{o} = btAll{i};
            o = o + 1;
        end
    end
end
irec = 1;
switch lower(method)
    case 'raw'
        % pass
    case 'merge'
        for i=1:length(pAll)
            mday = table;
            end_trial = 0;
            end_block = 0;
            timecompen = 0;
            tranSec = @(x) str2double(x(1:2))*3600+str2double(x(3:4))*60+str2double(x(5:6));
            for j=1:length(pAll{i})
                tday = btAll{pAll{i}(j)};
                tday.iTrial = tday.iTrial + end_trial;
                end_trial = tday.iTrial(end);
                tday.BlockNum = tday.BlockNum + end_block;
                end_block = tday.BlockNum(end);
                if j==1
                    timestart = tranSec(num2str(tday.StartTime(1)));
                else
                    timecompen = tranSec(num2str(tday.StartTime(1)))-timestart;
                end
                tday.TimeElapsed = tday.TimeElapsed + timecompen; %60s delay
                mday = [mday;tday];
            end
            out{rec(irec)} = mday;
            irec = irec + 1;
        end
    case 'select'
        for i=1:length(pAll)
            maxrow = 0;
            for j=1:length(pAll{i})
                tmprow = size(btAll{pAll{i}(j)},1);
                if tmprow>maxrow
                    maxrow = tmprow;
                    mday = btAll{pAll{i}(j)};
                end
            end
            out{rec(irec)} = mday;
            irec = irec + 1;
        end
end

end
