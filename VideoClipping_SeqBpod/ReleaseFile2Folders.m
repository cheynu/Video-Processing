clear;clc;
[filename,filepath] = uigetfile('Select the file');
file = fullfile(filepath,filename);

tarParPath = uigetdir('Select the parent folder of target folders');
tarPathDir = dir(tarParPath);
tarPathDir = tarPathDir(cellfun(@(x) x,{tarPathDir.isdir}));
tarPathName = {tarPathDir.name}';
tarPathName = tarPathName(cellfun(@(x) ~strcmp(x,'.') && ~strcmp(x,'..'),tarPathName));

for i=1:length(tarPathName)
    copyfile(file,fullfile(tarParPath,tarPathName{i}));
end