clear;clc;
%%
tarPath = uigetdir(pwd,'Select the folder to processed');
aviName = arrayfun(@(x) x.name, dir(fullfile(tarPath,'*.avi')),'UniformOutput',false);
folderName = unique(string(cellfun(@getDateChar,aviName,'UniformOutput',false)));
folderPath = fullfile(tarPath,folderName);
cellfun(@createFolder,folderPath);

for i=1:length(aviName)
    idx = find(contains(folderName,getDateChar(aviName{i})),1);
    if ~isempty(idx)
        movefile(fullfile(tarPath,aviName{i}),folderPath(idx));
        [~,pureaviname] = fileparts(aviName{i});
        txtfile = fullfile(tarPath,[pureaviname,'.txt']);
        if isfile(txtfile)
            movefile(txtfile,folderPath(idx));
        end
    end
end

%% Functions
function date = getDateChar(aviname)
    sepSite = strfind(aviname,'_');
    datechar = aviname(strfind(aviname,'+')+1:sepSite(4)-1);
    sepsite = strfind(datechar,'_');
    yyyy = datechar(1:sepsite(1)-1);
    mm = datechar(sepsite(1)+1:sepsite(2)-1);
    dd = datechar(sepsite(2)+1:end);
    if length(mm)<2
        mm = ['0',mm];
    end
    if length(dd)<2
        dd = ['0',dd];
    end
    date = [yyyy,mm,dd];
end

function createFolder(folderpath)
    if ~isfolder(folderpath)
        mkdir(folderpath);
    end
end