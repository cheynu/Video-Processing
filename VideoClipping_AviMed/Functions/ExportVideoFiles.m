function ExportVideoFiles(b, frameinfo, varargin)

% ExportVideoFiles(b, frameinfo, 'event', 'Press')
% this program export video clips from behavior-relevant time points.
% File name is : ANM_YearMonDay_Event###.avi
% Video files should be stored in current directory
% varargin:
% 'Event', 'Press'
% 'TimeRange': [2000 3000]
% 'RatName': 'Charlie'
% 'SessionName': '20200810'

% Jianing Yu
% 5/1/2021
remake = 0;
vid_fps = 10;

if nargin>2
    for i=1:2:size(varargin,2)
        switch varargin{i}
            case {'Event'}
                event = varargin{i+1};
            case {'TimeRange'}
                trange = varargin{i+1}; % pre- and post-event periods.
            case {'RatName'}
                anm = varargin{i+1}; % animal name
            case {'SessionName'}
                session = varargin{i+1}; % animal name
            case {'Remake'}
                remake =  varargin{i+1};
            otherwise
                errordlg('unknown argument')
        end
    end
end

tframesB            =    frameinfo.tFramesInB;
tpre                    =    trange(1); % pre event time included
tpost                   =     trange(2); % post event time included
trigger_dur         =     250; % trigger sitmulus is usually 250 ms

% identify video onset and offset
% beginning of new video segments (sometimes we record more than one video
% and there could be significan gap between these videos. obviously, events
% occuring within these gaps were not filmed.
ind_begs   =      [1 find(diff(tframesB)>1000)+1];
ind_ends   =      [find(diff(tframesB)>1000) length(tframesB)];
t_begs       =      tframesB(ind_begs); % beginning of each video segments, in behavior time
t_ends       =      tframesB(ind_ends); % ending of each video sgements, in behavior time

t_begs2     =      t_begs + tpre;
t_ends2     =      t_ends - tpost;

thisFolder = fullfile(pwd, 'VideoData', 'Clips');
if ~exist(thisFolder, 'dir')
    mkdir(thisFolder)
end

VidsMeta = struct('Session', [], 'Event', [], 'EventIndex', [], 'Performance', [], 'EventTime', [], 'FrameTimesB', [], 'VideoOrg', [], 'FrameIndx', [], 'Code', [], 'CreatedOn', []);

video_acc = 0;
switch event
    case {'press', 'Press'}
        event = 'Press';
        t_events               =          b.PressTime*1000;  % this is the press time
        t_rls                      =          b.ReleaseTime*1000;  % this is the press time
        % pull out a few critical events
        t_Press                 =           t_events;
        t_Release             =           b.ReleaseTime*1000;
        t_Trigger               =           b.TimeTone*1000;
        t_FPs                    =            b.FPs; % in ms
        % Extract video-tapped events.
        ind_event_incl      =           []; % events that were captured by video, index in b
        time_event_incl    =           []; % events that were captured by video, time in b
        for k=1:length(t_begs2)
            ind_event_incl          =       [ind_event_incl     find(t_events>t_begs2(k) & t_events<t_ends2(k))];                         % this is the press index
            time_event_incl        =       [time_event_incl    t_events(t_events>t_begs2(k) & t_events<t_ends2(k))];         % this is the time of these events, in ms
        end
        % now, start to extract video clip, one by one
        fbar = waitbar(0,'Time remaining: calculating...');
        clc
        costTime = [];
        for i =1:length(ind_event_incl)
            if i==1
                remainTime = 'calculating...';
            elseif toc(wtic)<1
                remainTimeS = mean(costTime).*(length(ind_event_incl)-i+1);
                remainTimeM = ceil(remainTimeS./60);
                if ~isnan(remainTimeM)
                    remainTime = [num2str(remainTimeM),' min'];
                else
                    remainTime = 'calculating...';
                end
            else
                costTime(end+1) = toc(wtic);
                remainTimeS = mean(costTime).*(length(ind_event_incl)-i+1);
                remainTimeM = ceil(remainTimeS./60);
                remainTime = [num2str(remainTimeM),' min'];
            end
            waitbar(i/length(ind_event_incl), fbar, ['Time remaining: ',remainTime]);
            wtic = tic;
            
            perf = [];
            % Performance and reaction time
            if ~isempty(find(b.Correct==ind_event_incl(i), 1))
                perf = 'Correct';
                RT = (b.ReleaseTime(ind_event_incl(i))-b.PressTime(ind_event_incl(i)))*1000 - b.FPs(ind_event_incl(i));
            elseif  ~isempty(find(b.Premature==ind_event_incl(i), 1))
                perf = 'Premature';
                RT = nan;
            elseif ~isempty(find(b.Late==ind_event_incl(i), 1))
                perf = 'Late';
                RT = (b.ReleaseTime(ind_event_incl(i))-b.PressTime(ind_event_incl(i)))*1000 - b.FPs(ind_event_incl(i));
            end
            
            % basic information of this event
            iFP = b.FPs(ind_event_incl(i)); % foreperiod
            if ~isempty(perf)
                video_name = sprintf('%s_%s_Press%03d', anm, session, ind_event_incl(i));
                
                % check if a video has been created and check if we want to
                % re-create the same video
                filename = fullfile(thisFolder, [video_name '.avi']);
                check_this_file = dir(filename);
                
                if isempty(check_this_file)  || remake % only make new video, unless told to remake all files.
                    % time and frames
                    IdxFrames              =       find(tframesB >= time_event_incl(i) - tpre & tframesB <= time_event_incl(i) + tpost); % these are the frame index (whole session)
                    FileIdx                      =      frameinfo.AviFileIndx(IdxFrames); % these are the file idx, one can track which video contains this event
                    VidFrameIdx           =       frameinfo.AviFrameIndx(IdxFrames);  % these are the frame index in video identified in FileIdx
                    itframes                   =       frameinfo.tFramesInB(IdxFrames);
                    itframes_norm        =       itframes -  time_event_incl(i);
                    tframes_highres      =       itframes(1):itframes(end);  % high resolution behavioral signals (1ms)
                    tframes_highres_norm      =       tframes_highres -  time_event_incl(i);
                    
                    uniFileIdx = unique(FileIdx);  %
                    FileNum = length(unique(FileIdx)); % usually only one, only rarely, one event is distributed in two video files, eg., xxx +, xxx ++, etc.
%                     img_extracted = uint8([]);
                    
                    for ifile = 1:FileNum
                        this_video = frameinfo.AviFile{uniFileIdx(ifile)};
                        vidObj = VideoReader(this_video);
                        IdxFrames_thisfile = FileIdx == uniFileIdx(ifile); % this video file
                        VidFrameIdx_thisfile = VidFrameIdx(IdxFrames_thisfile);  % these are the frame index in this video
                        frames_ifile = read(vidObj, [VidFrameIdx_thisfile(1) VidFrameIdx_thisfile(end)]);
%                         for ii =1:size(frames_ifile, 4)
%                             img_extracted = cat(3, img_extracted, rgb2gray(frames_ifile(:, :, :, ii)));
%                         end
                        gray_frames = cellfun(@(x) rgb2gray(x),...
                        squeeze(mat2cell(frames_ifile,size(frames_ifile,1),size(frames_ifile,2),size(frames_ifile,3),ones(1,size(frames_ifile,4)))),...
                            'UniformOutput',false);
                        img_extracted = cat(3,gray_frames{:,1});
                    end
                    clear frames_ifile gray_frames vidObj;
                    
                    % make press signal
                    if ~isempty(find(t_Press-itframes(1)>0 & t_Press-itframes(end)<0, 1))
                        presses_thisvid   =       t_Press(t_Press-itframes(1)>0 & t_Press-itframes(end)<0);
                        releases_thisvid   =       t_Release(t_Press-itframes(1)>0 & t_Press-itframes(end)<0);  % release may be out of the frame range
                    else
                        presses_thisvid   =       [];
                        releases_thisvid   =       [];
                    end
                    
                    press_signal = zeros(size(tframes_highres));
                    
                    if ~isempty(presses_thisvid)
                        for ipress = 1:length(presses_thisvid)
                            press_signal(tframes_highres>=presses_thisvid(ipress) & tframes_highres<=releases_thisvid(ipress)) = 2;
                        end
                    end
                    
                    % make trigger signal
                    if ~isempty(find(t_Trigger-itframes(1)>0 & t_Trigger-itframes(end)<0, 1))
                        trigger_incls   =  t_Trigger((t_Trigger-itframes(1)>0 & t_Trigger-itframes(end)<0));
                    else
                        trigger_incls   =       [];
                    end
                    
                    trigger_signal = NaN*ones(size(tframes_highres));
                    
                    if ~isempty(trigger_incls)
                        for itrigger = 1:length(trigger_incls)
                            trigger_signal(tframes_highres>=trigger_incls(itrigger) & tframes_highres<=trigger_incls(itrigger)+trigger_dur) = 3;
                        end
                    end
                    
                    % build video clips, frame by frame
                    
                    VidMeta.Session               =          b.SessionName;
                    VidMeta.Event                   =          event;
                    VidMeta.EventIndex          =           ind_event_incl(i);
                    VidMeta.Performance       =           perf;
                    VidMeta.EventTime           =           time_event_incl(i);       % Event time in ms in behavior time
                    VidMeta.FrameTimesB     =           itframes;                        % frame time in ms in behavior time
                    VidMeta.VideoOrg            =           this_video;
                    VidMeta.FrameIndx          =            VidFrameIdx;                   % frame index in original video
                    VidMeta.Code                   =             mfilename('fullpath');
                    VidMeta.CreatedOn          =            date;                                % today's date
                    
                    video_acc = video_acc+1;
                    VidsMeta(video_acc) = VidMeta;
                    
                    img_height = size(img_extracted,1);
                    img_width = size(img_extracted,2);
                    
                    hf24 = figure(24); clf(hf24,'reset');
                    set(hf24, 'name', 'side view', 'units', 'centimeters', 'position', [3 5 15 3+15*img_height/img_width],...
                        'PaperPositionMode', 'auto', 'color', 'w', 'renderer','opengl','toolbar','none','resize','off')

                    ha = axes;
                    set(ha, 'units', 'centimeters', 'position', [0 3 15 15*img_height/img_width], 'nextplot', 'add', 'xlim',[0 img_width], 'ylim', [0 img_height], 'ydir','reverse')
                    axis off
                    % plot this frame:
                    img = imagesc(ha, img_extracted(:, :, 1), [0 255]);
                    colormap('gray')
                    
                    % plot some behavior data
%                     time_of_frame = sprintf('%3.0f', round(itframes_norm(1)));
%                     text(10, 30, [time_of_frame ' ms'], 'color', [246 233 35]/255, 'fontsize', 12,'fontweight', 'bold')
%                     text(10, 830,  sprintf('%s',b.SessionName(1:10)), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
%                     text(10, 870,  sprintf('%s %03d', event, ind_event_incl(i)), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
%                     text(10, 910,  sprintf('FP %2.0fms', iFP), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
%                     text(10, 950,  sprintf('RT %2.0fms', RT), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
%                     text(10, 990,  perf, 'fontsize',  10, 'fontweight', 'bold','color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
                    seqTxt = max(40,ceil(img_height/25));
                    time_of_frame = sprintf('%3.0f', round(itframes_norm(1)));
                    time_text = text(10, seqTxt, [time_of_frame ' ms'], 'color', [246 233 35]/255, 'fontsize', 12,'fontweight', 'bold');
%                     text(10, 70, [num2str(vid_fps),' FPS'], 'color', [246 233 35]/255, 'fontsize', 10,'fontweight', 'bold')
                    text(10, img_height-seqTxt*6,  sprintf('%s',anm), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold');
                    text(10, img_height-seqTxt*5,  sprintf('%s',session), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
                    text(10, img_height-seqTxt*4,  sprintf('%s %03d', event, ind_event_incl(i)), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
                    text(10, img_height-seqTxt*3,  sprintf('FP %2.0f ms', iFP), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
                    text(10, img_height-seqTxt*2,  sprintf('RT %2.0f ms', RT), 'color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')
                    text(10, img_height-seqTxt,  perf, 'fontsize',  10, 'fontweight', 'bold','color', [255 255 255]/255, 'fontsize',  10, 'fontweight', 'bold')

                     % plot some important behavioral events
                    ha2 = axes;
                    set(ha2, 'units', 'centimeters', 'position', [0.5 0.75 15-1 2], 'nextplot', 'add', 'xlim',[-tpre-100 tpost], 'xtick', [-5000:1000:5000], 'ytick', [0.5 2.5],'yticklabel', {'Press', 'Trigger'},'ylim', [-0.5 4], 'tickdir', 'out', 'ycolor', 'none')

                    indplot = find(tframes_highres <= itframes(1), 1, 'last');

                    plot(tframes_highres_norm, press_signal, 'k', 'linewidth', 2);
                    dot = plot(tframes_highres_norm(indplot), press_signal(indplot), 'bo', 'linewidth', 2, 'markersize', 6, 'markerfacecolor', 'b');
                    text(tframes_highres_norm(1)-100, 0.8, 'Press','fontsize', 10, 'color', 'k', 'fontweight', 'bold')

                    plot(tframes_highres_norm, trigger_signal, 'color', [255 140 0]/255, 'linewidth', 2);
                    text(tframes_highres_norm(1)-100, 3.2, 'Trigger','fontsize', 10, 'color', 'k', 'fontweight', 'bold', 'color', [255 140 0]/255)
                    
                    F = struct('cdata', [], 'colormap', []);
                    F(1) = getframe(hf24);
                    
                    for k=2:size(img_extracted, 3)
                        time_of_frame = sprintf('%3.0f', round(itframes_norm(k)));
                        time_text.String = [time_of_frame ' ms'];
                        
                        indplot = find(tframes_highres < itframes(k), 1, 'last');
                        dot.XData = tframes_highres_norm(indplot);
                        dot.YData = press_signal(indplot);
                        
                        img.CData = img_extracted(:, :, k);
                        drawnow;
                       
                        % plot or update data in this plot
                        F(k) = getframe(hf24);
                    end
                    clear img_extracted;
                    % make a video clip and save it to the correct location
                    writerObj = VideoWriter(filename);
                    writerObj.FrameRate = vid_fps; % set the seconds per image
                    % open the video writer
                    open(writerObj);
                    % write the frames to the video
                    writeVideo(writerObj,F);
                    % close the writer object
                    close(writerObj);
                    clear writerObj F;
                    
                    MetaFileName = fullfile(thisFolder, [video_name, '.mat']);
                    save(MetaFileName, 'VidMeta');
                end
            end
        end
        video_meta = sprintf('%s_%s_PressVideosMeta', anm, session);
        save(video_meta, 'VidsMeta');
        waitbar(1, fbar, 'Complete');
    otherwise
        errodlg('No idea what you want')
end
end

