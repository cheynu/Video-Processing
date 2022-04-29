function bt = DSRT_DataExtract_Block(filename,plotmark,path_arc)

switch nargin
    case 1
        plotmark = true;
        path_arc = pwd;
    case 2
        path_arc = pwd;
    case 3
        if ~isfolder(path_arc)
            path_arc = pwd;
        end
    otherwise
        error('Invalid input argument number');
end

load(filename);
data = SessionData;

% get sbj name and session date from filename
dname = split(string(filename), '_');
newName = dname(1);
newDate = str2double(dname(5));
Tstart = str2double(datestr(data.Info.SessionStartTime_MATLAB,'HHMMSS'));
newTask = dname(4);
nTrials = data.nTrials;
cellCustom = struct2cell(data.Custom);
for i=1:length(cellCustom)
    if nTrials > length(cellCustom{i})
        nTrials = length(cellCustom{i});
        display(newName+"_"+newTask+"_"+newDate+"_CustomTrials ~= nTrials");
    end
end

Name = repelem(newName,nTrials)';
Date = repelem(newDate,nTrials)';
StartTime = repelem(Tstart,nTrials)';
Task = repelem(newTask,nTrials)';
iTrial = (1:nTrials)';
if ~isfield(data.Custom,'BlockNum')
    BlockNum = ones(nTrials,1);
    TrialNum = (1:nTrials)';
    TrialType = zeros(nTrials,1); % all is lever
else
    BlockNum = data.Custom.BlockNum(1:nTrials)';
    TrialNum = data.Custom.TrialNum(1:nTrials)';
    TrialType = data.Custom.TrialType(1:nTrials)';
end
TimeElapsed = data.Custom.TimeElapsed(1:nTrials)'; % start press or poke: wait4tone(1)
TimeElapsed(TimeElapsed>1e4) = NaN;
FP = round(data.Custom.ForePeriod(1:nTrials),1)';
RW = data.Custom.ResponseWindow(1:nTrials)';
DarkTry = [];
ConfuseNum = []; % e.g., try to poke in lever block
Outcome = data.Custom.OutcomeCode(1:nTrials)';
HT = []; % hold time
RT = data.Custom.ReactionTime(1:nTrials)';
MT = data.Custom.MovementTime(1:nTrials)';

alterTE = false;
if isnan(TimeElapsed)
    TimeElapsed = zeros(nTrials,1).*NaN;
    alterTE = true;
end

for i = 1:nTrials
    if isfield(data.RawEvents.Trial{1,i}.States,'TimeOut_reset') % dark try num
        if ~isnan(data.RawEvents.Trial{1,i}.States.TimeOut_reset)
            DarkTry = [DarkTry; size(data.RawEvents.Trial{1,i}.States.TimeOut_reset,1)];
        else
            DarkTry = [DarkTry; 0];
        end
    else
        DarkTry = [DarkTry; 0];
    end
    switch TrialType(i) % confuse try num
        case 0 % lever
            if isfield(data.RawEvents.Trial{1,i}.Events,'Port2In')
                ConfuseNum = [ConfuseNum; length(data.RawEvents.Trial{1,i}.Events.Port2In)];
            else
                ConfuseNum = [ConfuseNum; 0];
            end
        case 1 % poke
            if isfield(data.RawEvents.Trial{1,i}.Events,'BNC1High')
                ConfuseNum = [ConfuseNum; length(data.RawEvents.Trial{1,i}.Events.BNC1High)];
            elseif isfield(data.RawEvents.Trial{1,i}.Events,'RotaryEncoder1_1')
                ConfuseNum = [ConfuseNum; length(data.RawEvents.Trial{1,i}.Events.RotaryEncoder1_1)];
            else
                ConfuseNum = [ConfuseNum; 0];
            end
    end
    if isnan(data.RawEvents.Trial{1, i}.States.Wait4Tone) % HT start time
        if isfield(data.RawEvents.Trial{1, i}.States,'Delay')
            HT_ori = data.RawEvents.Trial{1, i}.States.Delay(2);
        else
            HT_ori = data.RawEvents.Trial{1, i}.Wait4Start(2);
        end
    else
        HT_ori = data.RawEvents.Trial{1, i}.States.Wait4Tone(end,1);
    end
    switch Outcome(i) % HT
        case 1
            HT = [HT; ...
                data.RawEvents.Trial{1, i}.States.Wait4Stop(2) - HT_ori];
        case -1
            if isfield(data.RawEvents.Trial{1, i}.States,'GracePeriod')
                HT = [HT;...
                    data.RawEvents.Trial{1, i}.States.GracePeriod(end,1) - HT_ori];
            else
                HT = [HT;...
                    data.RawEvents.Trial{1, i}.States.Premature(1) - HT_ori];
            end
        case -2
            HT = [HT;...
                data.RawEvents.Trial{1, i}.States.LateError(2) - HT_ori];
        otherwise
            HT = [HT;NaN];
    end
    if alterTE
        TimeElapsed(i) = data.TrialStartTimestamp(i) + HT_ori;
    end
end
% adjust name
ind_lever = TrialType == 0;
ind_poke  = TrialType == 1;
newType = string(TrialType);
newType(ind_lever) = repelem("Lever",sum(ind_lever))';
newType(ind_poke) = repelem("Poke" ,sum(ind_poke))';

ind_cor  = Outcome ==  1;
ind_pre  = Outcome == -1;
ind_late = Outcome == -2;
newOutcome = string(Outcome);
newOutcome(ind_cor) = repelem("Cor",sum(ind_cor)');
newOutcome(ind_pre) = repelem("Pre",sum(ind_pre)');
newOutcome(ind_late) = repelem("Late",sum(ind_late)');
% create table
tablenames = {'Subject','Date','StartTime','Task','iTrial','BlockNum','TrialNum','TrialType',...
    'TimeElapsed','FP','RW','DarkTry','ConfuseNum','Outcome','HT','RT','MT'};
bt = table(Name,Date,StartTime,Task,iTrial,BlockNum,TrialNum,newType,...
    TimeElapsed,FP,RW,DarkTry,ConfuseNum,newOutcome,HT,RT,MT,...
    'VariableNames',tablenames);

savename = 'B_' + upper(newName) + '_' + strrep(num2str(newDate), '-', '_') + '_' +...
    strrep(data.Info.SessionStartTime_UTC,':', '');
save(savename,'bt');
%% Plot progress
cTab10 = [0.0901960784313726,0.466666666666667,0.701960784313725;0.960784313725490,0.498039215686275,0.137254901960784;0.152941176470588,0.631372549019608,0.278431372549020;0.843137254901961,0.149019607843137,0.172549019607843;0.564705882352941,0.403921568627451,0.674509803921569;0.549019607843137,0.337254901960784,0.290196078431373;0.847058823529412,0.474509803921569,0.698039215686275;0.501960784313726,0.501960784313726,0.501960784313726;0.737254901960784,0.745098039215686,0.196078431372549;0.113725490196078,0.737254901960784,0.803921568627451];
cTab20 = [0.0901960784313726,0.466666666666667,0.701960784313725;0.682352941176471,0.780392156862745,0.901960784313726;0.960784313725490,0.498039215686275,0.137254901960784;0.988235294117647,0.729411764705882,0.470588235294118;0.152941176470588,0.631372549019608,0.278431372549020;0.611764705882353,0.811764705882353,0.533333333333333;0.843137254901961,0.149019607843137,0.172549019607843;0.964705882352941,0.588235294117647,0.592156862745098;0.564705882352941,0.403921568627451,0.674509803921569;0.768627450980392,0.690196078431373,0.827450980392157;0.549019607843137,0.337254901960784,0.290196078431373;0.768627450980392,0.607843137254902,0.576470588235294;0.847058823529412,0.474509803921569,0.698039215686275;0.956862745098039,0.709803921568628,0.807843137254902;0.501960784313726,0.501960784313726,0.501960784313726;0.780392156862745,0.780392156862745,0.776470588235294;0.737254901960784,0.745098039215686,0.196078431372549;0.854901960784314,0.862745098039216,0.549019607843137;0.113725490196078,0.737254901960784,0.803921568627451;0.627450980392157,0.843137254901961,0.890196078431373];
cGreen = cTab10(3,:);
cGreen2 = cTab20(5:6,:);
cRed = cTab10(4,:);
cRed2 = cTab20(7:8,:);
cGray = cTab10(8,:);
cGray2 = cTab20(15:16,:);

cCor_Pre_Late = [cGreen;cRed;cGray];
cCor_Pre_Late2 = [cGreen2;cRed2;cGray2];
cCor_Late = [cGreen;cGray];

if plotmark
    progFig = figure(1); clf(progFig);
    style = 2;
    switch style
        case 1
            set(progFig, 'Name','ProgFig','unit', 'centimeters', 'position',[1 1 24 14], ...
            'paperpositionmode', 'auto');

            g(1,1) = gramm('x',bt.TimeElapsed,'y',bt.HT,'color',cellstr(bt.Outcome));
            g(1,1).facet_grid(cellstr(bt.TrialType),[]);
            g(1,1).axe_property('xlim',[0 4200],'ylim', [0 3.1],'XGrid', 'on', 'YGrid', 'on');
            g(1,1).geom_point('alpha',0.8);g.set_point_options('base_size',5);
            g(1,1).set_names('x','Time(s)','y','HT(s)','color','','lightness','','row','');
            g(1,1).set_color_options('map',cCor_Pre_Late,'n_color',3,'n_lightness',1);
            g(1,1).set_order_options('color',{'Cor','Pre','Late'});
            g(1,1).set_layout_options('legend_position',[0.45,0.75,0.12,0.2]);
            
            g(1,2) = gramm('x',bt.TimeElapsed,'y',bt.RT,'color',cellstr(bt.Outcome),'subset',bt.Outcome~="Pre");
            g(1,2).facet_grid(cellstr(bt.TrialType),[]);
            g(1,2).axe_property('xlim',[0 4200],'ylim', [0 2.1],'XGrid', 'on', 'YGrid', 'on');
            g(1,2).geom_point('alpha',0.8);g(1,2).set_point_options('base_size',5);
            g(1,2).set_names('x','Time(s)','y','RT(s)','color','','lightness','','row','');
            g(1,2).set_color_options('map',cCor_Late,'n_color',2,'n_lightness',1);
            g(1,2).set_order_options('color',{'Cor','Late'});
            g(1,2).no_legend;
            
            g.set_title(savename);
            g.draw();
            
            obj_lever = findobj(g(1,1).facet_axes_handles(1,1),'String','Lever');
            obj_lever.String = '';
            obj_poke = findobj(g(1,1).facet_axes_handles(2,1),'String','Poke');
            obj_poke.String = '';
        case 2
            set(progFig, 'Name','ProgFig','unit', 'centimeters', 'position',[1 1 24 18], ...
            'paperpositionmode', 'auto');

            bt_plot = stack(bt,{'HT','RT'});
            g(1,1) = gramm('x',bt_plot.TimeElapsed,'y',bt_plot.HT_RT,'color',cellstr(bt_plot.Outcome));
            g(1,1).facet_grid(cellstr(bt_plot.TrialType),bt_plot.HT_RT_Indicator);
            g(1,1).axe_property('ylim',[0 3],'XGrid', 'on', 'YGrid', 'on');
            g(1,1).geom_point('alpha',0.7); g(1,1).set_point_options('base_size',5);
            g(1,1).set_names('x','Time(s)','y','','color','','lightness','','column','','row','');
            g(1,1).set_color_options('map',cCor_Pre_Late,'n_color',3,'n_lightness',1);
            g(1,1).set_order_options('color',{'Cor','Pre','Late'},'column',{'HT','RT'});
%             g(1,1).set_layout_options();
            g(1,1).no_legend;
            
            g(2,1) = gramm('x',bt.TimeElapsed,'y',bt.iTrial,'color',cellstr(bt.Outcome),...
                'lightness',cellstr(bt.TrialType));
            g(2,1).axe_property('XGrid', 'on', 'YGrid', 'on');
            g(2,1).geom_point('alpha',0.7); g(2,1).set_point_options('base_size',5);
            g(2,1).set_names('x','Time(s)','y','Trial#','color','Color','lightness','Lightness');
            g(2,1).set_color_options('map',cCor_Pre_Late2,'n_color',3,'n_lightness',2);
            g(2,1).set_order_options('color',{'Cor','Pre','Late'},'lightness',{'Lever','Poke'});
            g(2,1).set_layout_options('legend_position',[0.89,0.07,0.13,0.3]);

            g.set_title(savename);
            g.draw();

            obj_ht = findobj(g(1,1).facet_axes_handles(1,1),'String','HT');
            obj_ht.String = 'HT (s)';
            obj_rt = findobj(g(1,1).facet_axes_handles(1,2),'String','RT');
            obj_rt.String = 'RT (s)';
    end
    
    figPath = fullfile(path_arc,'ProgFig',newName);
    if ~exist(figPath,'dir')
        mkdir(figPath);
    end
    figFile = fullfile(figPath,savename);
    saveas(progFig, figFile, 'png');
    saveas(progFig, figFile, 'fig');
end

end