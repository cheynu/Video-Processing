function FrameInfo = GetSeqFrameInfo_Bpod(frame_range,BpodFile)
switch nargin
    case 0
        frame_range = [0,1]+5*60*50;
        BpodFile = arrayfun(@(x)x.name, dir('*DSRT*.mat'), 'UniformOutput', false);
    case 1
        BpodFile = arrayfun(@(x)x.name, dir('*DSRT*.mat'), 'UniformOutput', false);
    otherwise
        % pass
end
%% Extract mask, use frames from 5min*60s/min*50frame/s to 6min*60*50 (default)
SeqVidFile = arrayfun(@(x)x.name, dir('*.seq'), 'UniformOutput', false);

mask = ExtractMaskSeq(SeqVidFile{1}, frame_range);
%% based on "mask", extract pixel intensity in ROI from all frames
tsROI = [];
SummedROI = [];
SeqFrameIndx = [];
SeqFileIndx = [];

numFrames = [];
for i=1:length(SeqVidFile)
    [~,headerInfo] = ReadJpegSEQ(SeqVidFile{i}, [1 1]);
    numFrames = [numFrames,headerInfo.AllocatedFrames];
end
allFrames = sum(numFrames);

costTime = nan(1,ceil(allFrames/100));
fbar = waitbar(0,'Masking time remaining: calculating...');
for i=1:length(SeqVidFile)
    %  Read all frames:
    tstart = 0;
    for kframe=1:numFrames(i)
        if isnan(costTime(1))
            costTime(1) = 0;
            wtic = tic;
        elseif rem(kframe,100)==0
            costTime(kframe/100) = toc(wtic);
            remainTimeS = mean(costTime,'omitnan').*sum(isnan(costTime));
            remainTimeM = ceil(remainTimeS./60);
            remainTime = [num2str(remainTimeM),' min'];
            waitbar(kframe/allFrames, fbar, ['Masking time remaining: ',remainTime]);
            wtic = tic;
        end
        
        thisFrame = ReadJpegSEQ(SeqVidFile{i}, [kframe kframe]);
        imgOut    = double(thisFrame{1});
        tf        = thisFrame{2};
        
        roi_k = sum(imgOut(mask));

        tf_hr = str2num(tf([13 14]))*3600*1000;
        tf_mn = str2num(tf([16 17]))*60*1000;
        tf_ss = str2num(tf([19 20]))*1000;
        tf_ms = str2num(tf([22:end]))/1000;

        tf_current = round(sum([tf_hr, tf_mn, tf_ss, tf_ms]));
        if kframe == 1
            tstart = tf_current;
        end
        tf_current = tf_current - tstart;

        tsROI           = [tsROI tf_current];
        SummedROI       = [SummedROI roi_k];
        SeqFrameIndx    = [SeqFrameIndx kframe];
        SeqFileIndx     = [SeqFileIndx i];
    end
end
close(fbar);

tsROI = tsROI - tsROI(1); % onset normalized to 0
FrameInfo               = [];
FrameInfo.tframe        = tsROI;
FrameInfo.mask          = mask;
FrameInfo.ROI           = SummedROI;
FrameInfo.SeqVidFile    = SeqVidFile;
FrameInfo.SeqFileIndx   = SeqFileIndx;
FrameInfo.SeqFrameIndx  = SeqFrameIndx;
FrameInfo.Bpodfile      = BpodFile;

%% Save (because it takes a long time to get tsROI)
save FrameInfo FrameInfo
end

