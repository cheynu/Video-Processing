%% Initialize
clear;clc;
path_func = 'C:\Users\CY\OneDrive\lab\VideoProcessing\VideoClipping_SeqBpod\Functions';
if isempty(path_func) || ~isfolder(path_func)
    path_func = uigetdir(pwd,'Select the path containing necessary functions');
end
if isfolder(string(path_func))
    addpath(path_func);
end
%% Extract Seq & Bpod data for aligning
BpodFile = arrayfun(@(x)x.name, dir('*DSRT*.mat'), 'UniformOutput', false);

% FrameInfo = GetSeqFrameInfo_Bpod([0 0.5*60*50]+5*60*50,BpodFile);
GetSeqFrameInfo_Bpod([0 0.5*60*50]+5*60*50,BpodFile);
load('FrameInfo.mat');

% FrameInfo = 
%   struct with fields:
%           tframe: [1�152719 double]   %timpstamp in video reference
%             mask: [1080�1440 logical] %mask location
%              ROI: [1�152719 double]   %sum of mask pixels
%       SeqVidFile: {'20210330-12-23-00.000.seq'}
%      SeqFileIndx: [1�152719 double]   %belong to which seq file
%     SeqFrameIndx: [1�152719 double]   %the order of frames
%          MEDfile: '2021-03-30_12h14m_Subject Pineapple.txt'
btAll = cell(1,length(FrameInfo.Bpodfile));
for i=1:length(btAll)
    btAll{i} = DSRT_DataExtract_Block(FrameInfo.Bpodfile{i},false);
end
if length(btAll)>1 % unfinished
    btAll = DSRT_DataMerge_Block(btAll,2); % merge
    bt = btAll{1};
    spname = split(string(FrameInfo.Bpodfile{1}), '_');
    BpodSbj = spname(1);
    save('bmixedAll_'+BpodSbj, 'bt');
else
    bt = btAll{1};
end

tbeh_trigger = 1000.* (bt.TimeElapsed(bt.Outcome~="Pre") + bt.FP(bt.Outcome~="Pre"));

%% Extract LED-On time
tLEDon = FindLEDon(FrameInfo.tframe, FrameInfo.ROI);

Indout = findseqmatch(tbeh_trigger-tbeh_trigger(1), tLEDon-tLEDon(1), 1);
% these LEDon times are the ones that cannot be matched to trigger. It must be a false positive signal that was picked up by mistake in "tLEDon = FindLEDon(tsROI, SummedROI);"
ind_badROI = find(isnan(Indout));
tLEDon(ind_badROI) = []; % remove them
Indout(ind_badROI) = []; % at this point, each LEDon time can be mapped to a trigger time in b (Indout)
FrameInfo.tLEDon = tLEDon; % time when LED turns on
FrameInfo.Indout = Indout; % index of each seqson's element in seqmom
%% Now, let's redefine the frame time. Each frame time should be re-mapped to the timespace in b.
% all frame times are here: FrameInfo.tframe
tframes_in_b = MapVidFrameTime2B(FrameInfo.tLEDon, tbeh_trigger, Indout, FrameInfo.tframe);
FrameInfo.tFramesInB = tframes_in_b; %timpstamp in bpod reference

 %% Empirically, some events are still not well aligned. In particually, in a small subset of trials, LED starts to light up at trigger time we need to revise these trials.
imhappy = 0;
while ~imhappy
    % some tLEDon need to be revised.
    
    tLEDon = CorrectLEDtime_Bpod(bt, FrameInfo); % update tLEDon
    Indout = findseqmatch(tbeh_trigger-tbeh_trigger(1), tLEDon, 1);
    % these LEDon times are the ones that cannot be matched to trigger. It must be a false positive signal that was picked up by mistake in "tLEDon = FindLEDon(tsROI, SummedROI);"
    ind_badROI = find(isnan(Indout));
    tLEDon(ind_badROI) = []; % remove them
    Indout(ind_badROI) = []; % at this point, each LEDon time can be mapped to a trigger time in b (Indout)
    FrameInfo.tLEDon = tLEDon;
    FrameInfo.Indout = Indout;
    tframes_in_b = MapVidFrameTime2B(FrameInfo.tLEDon,  tbeh_trigger, Indout, FrameInfo.tframe);
    FrameInfo.tFramesInB = tframes_in_b;
    clc
%     reply = input('Are you happy? Y/N [Y]', 's');
    reply = questdlg('Are you happy?','Confirm','Happy','Unhappy','Happy');
    if isempty(reply)
        reply = 'Happy';
    end
    if strcmp(reply, 'Happy')
        imhappy = 1;
    else
        imhappy = 0;
    end
end
%% check if the LED ON/OFF looks right around trigger stimulus
roi_collect = CheckSeqFrameTrigger_Bpod(bt, FrameInfo);
%% Check if Press and Release look alright
CheckSeqFramePressRelease_Bpod(bt, FrameInfo);
%% Save
save FrameInfo FrameInfo
%% Make Video
load('FrameInfo.mat');

spname = split(string(FrameInfo.Bpodfile{1}), '_');
BpodSbj = spname(1);
BpodDate = spname(5);
ExportSeqVideoFiles_Bpod(bt, FrameInfo, 'Event', 'Trialstart', 'TimeRange', [2000 3000], 'SessionName',BpodDate, 'RatName', BpodSbj, 'Remake', 1);