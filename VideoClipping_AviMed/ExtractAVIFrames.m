%% Initialize
clear;clc;
path_func = 'C:\Users\CY\OneDrive\lab\VideoProcessing\VideoClipping_AviMed\Functions';
addpath(path_func);
if isempty(path_func) || ~isfolder(path_func)
    path_func = uigetdir(pwd,'Select the path containing necessary functions');
end
if isfolder(string(path_func))
    addpath(path_func);
end
%% This command will be run in the end. 
Extrct      = "ExportVideoFiles(b, FrameInfo, 'Event', 'Press', 'TimeRange', [2000 3000], 'SessionName',strrep(FrameInfo.MEDfile(1:10), '-', ''), 'RatName', FrameInfo.MEDfile(27:strfind(FrameInfo.MEDfile, '.')-1), 'Remake', 0)";
MakeSheet   = "MakeSpreadSheet(b, FrameInfo, 'Event', 'Press', 'TimeRange', [2000 3000], 'SessionName', strrep(FrameInfo.MEDfile(1:10), '-', ''), 'RatName', FrameInfo.MEDfile(27:strfind(FrameInfo.MEDfile, '.')-1))";
%% Extract video info for aligning
fileinfo = FindAviFiles;
GetFrameInfo(fileinfo,[0 0.2*60*50]+5*60*50);
%% next, map tLEDon to b's  TimeTone: [1�200 double]
load('FrameInfo.mat');
% tone time is stored in "b", which is derived from  track_training_progress_advanced(MEDfile);
if isempty(dir(['B_*.mat']))
    track_training_progress_advanced(FrameInfo.MEDfile);
end
behfile= dir('B_*mat');
load(fullfile(behfile.folder, behfile.name))
tbeh_trigger = b.TimeTone*1000;  % in ms
%%  The goal is to align tLEDon and tbeh_trigger
% alignment and print
%% extract LED-On time
tLEDon = FindLEDon(FrameInfo.tframe, FrameInfo.ROI);
Indout = findseqmatch(tbeh_trigger-tbeh_trigger(1), tLEDon-tLEDon(1), 1);
% these LEDon times are the ones that cannot be matched to trigger. It must be a false positive signal that was picked up by mistake in "tLEDon = FindLEDon(tsROI, SummedROI);"
ind_badROI = find(isnan(Indout));
tLEDon(ind_badROI) = []; % remove them
Indout(ind_badROI) = []; % at this point, each LEDon time can be mapped to a trigger time in b (Indout)
FrameInfo.tLEDon = tLEDon;
FrameInfo.Indout = Indout;
%% Now, let's redefine the frame time. Each frame time should be re-mapped to the timespace in b.
% all frame times are here: FrameInfo.tframe
tframes_in_b = MapVidFrameTime2B(FrameInfo.tLEDon,  tbeh_trigger, Indout, FrameInfo.tframe);
FrameInfo.tFramesInB = tframes_in_b;

imhappy = 0;
while ~imhappy
    %% Empirically, some events are still not well aligned. In particually, in a small subset of trials, LED starts to light up at trigger time we need to revise these trials.
    % some tLEDon need to be revised.
    
    tLEDon = CorrectLEDtime(b, FrameInfo); % update tLEDon
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
roi_collect = CheckAVIFrameTrigger(b, FrameInfo);
%% Check if Press and Release look alright
CheckAVIFramePressRelease(b, FrameInfo)
save FrameInfo FrameInfo
%% Extract clips
eval(Extrct)
eval(MakeSheet)