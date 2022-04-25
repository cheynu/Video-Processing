function FrameInfo = GetFrameInfo(fileinfo,frame_range)
%These are the required video and behavioral files.
 
VidFiles = fileinfo.Vids;
TsFiles = fileinfo.Txts;
MEDfile = fileinfo.MED;

mask = ExtractMask(VidFiles{1}, frame_range);
%% based on "mask", extract pixel intensity in ROI from all frames
numFrames = [];
for i=1:length(VidFiles)
    vidObj = VideoReader(VidFiles{i});
    numFrames = [numFrames,vidObj.NumFrames];
    clear vidObj;
end
allFrames = sum(numFrames);

tsROI           = nan(1,allFrames);
SummedROI       = nan(1,allFrames);
AviFrameIndx    = nan(1,allFrames);
AviFileIndx     = nan(1,allFrames);

if length(VidFiles)==length(TsFiles)
    Only1Ts = false;
else
    Only1Ts = true;
end

lenTiming = 500;
costTime = nan(1,ceil(allFrames/lenTiming));
fbar = waitbar(0,'Masking time remaining: calculating...');
idxFrame = 1;
for i=1:length(VidFiles)
    if ~Only1Ts
        fileID = fopen(TsFiles{i}, 'r');
    else
        fileID = fopen(TsFiles{1}, 'r');
    end
    formatSpec   = '%f' ;
    NumOuts      = fscanf(fileID, formatSpec); % this contains frame time (in ms) and frame index    
    fclose(fileID);
    
    ind_brk = find(NumOuts==0);
    FrameTs = NumOuts(1:ind_brk-1);  % frame times
%     FrameIdx = NumOuts(ind_brk+1:end);  % frame idx    
    filename = VidFiles{i};
    vidObj = VideoReader(filename);
    for k=1:vidObj.NumFrames
        if idxFrame==1
            wtic = tic;
        elseif rem(idxFrame,lenTiming)==0
            costTime(idxFrame/lenTiming) = toc(wtic);
            remainTimeS = mean(costTime,'omitnan').*sum(isnan(costTime));
            remainTimeM = ceil(remainTimeS./60);
            remainTime = [num2str(remainTimeM),' min'];
            waitbar(idxFrame/allFrames, fbar, ['Masking time remaining: ',remainTime]);
            wtic = tic;
        end
        
        thisFrame = read(vidObj, k);
        thisFrame = thisFrame(:, :, 1);
        roi_k = sum(thisFrame(mask));
        if ~Only1Ts
            tsROI(idxFrame) = FrameTs(k);
        else
            tsROI(idxFrame) = FrameTs(idxFrame);
        end
        SummedROI(idxFrame)     = roi_k;
        AviFileIndx(idxFrame)   = i;
        AviFrameIndx(idxFrame)  = k;
        
        idxFrame = idxFrame + 1;
    end
    clear vidObj;
end
close(fbar);

tsROI = tsROI - tsROI(1); % onset normalized to 0
FrameInfo               = [];
FrameInfo.tframe        = tsROI;
FrameInfo.mask          = mask;
FrameInfo.ROI           = SummedROI;
FrameInfo.AviFile       = VidFiles;
FrameInfo.AviFileIndx	= AviFileIndx;
FrameInfo.AviFrameIndx	= AviFrameIndx;
FrameInfo.MEDfile       = MEDfile;

%% Save for now because it takes a long time to get tsROI
save FrameInfo FrameInfo
end

