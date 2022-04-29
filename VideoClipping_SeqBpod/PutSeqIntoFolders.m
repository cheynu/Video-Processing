clear;clc;
%%
tarPath = uigetdir(pwd,'Select the folder to processed');
seqName = arrayfun(@(x) x.name, dir(fullfile(tarPath,'*.seq')),'UniformOutput',false);
folderName = unique(string(cellfun(@(x) x(1:8),seqName,'UniformOutput',false)));
folderPath = fullfile(tarPath,folderName);
cellfun(@createFolder,folderPath);

for i=1:length(seqName)
    idx = find(contains(folderName,seqName{i}(1:8)),1);
    if ~isempty(idx)
        movefile(fullfile(tarPath,seqName{i}),folderPath(idx));
        movefile(fullfile(tarPath,[seqName{i},'.idx']),folderPath(idx));
    end
end

%% Functions
function createFolder(folderpath)
    if ~isfolder(folderpath)
        mkdir(folderpath);
    end
end