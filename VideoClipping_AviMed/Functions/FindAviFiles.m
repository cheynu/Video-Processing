function fileinfo = FindAviFiles

% 5/6/2021
% This is to find avi files in current folder. as well as the associated
% txt files

% xfiles = dir('Cam*.avi');
% nfiles = length(xfiles);
% 
% datefiles   =   [];
% vfiles      =   {};
% txtfiles    =   {};
% for i=1:nfiles
%     vfiles{i}       =   xfiles(i).name;
%     txtfiles{i}     =   strrep(xfiles(i).name, 'avi', 'txt');
%     datefiles(i)    =   xfiles(i).datenum;
% end

% sort dates
% 
% [~, indsort] = sort(datefiles);
% VidFiles = vfiles(indsort);
% TxtFiles  = txtfiles(indsort);

vfiles = arrayfun(@(x) x.name,dir('Cam*.avi'),'UniformOutput',false);
vdates = arrayfun(@(x) x.datenum,dir('Cam*.avi'));
[~,indsort] = sort(vdates);
VidFiles = vfiles(indsort);

txtfiles = arrayfun(@(x) x.name,dir('Cam*.txt'),'UniformOutput',false);
txtdates = arrayfun(@(x) x.datenum,dir('Cam*.txt'));
[~,indsort] = sort(txtdates);
TxtFiles = txtfiles(indsort);

fileinfo.Vids = VidFiles;
fileinfo.Txts = TxtFiles;

MEDfiles = dir('*Subject*.txt');

if ~isempty(MEDfiles)
    fileinfo.MED = MEDfiles.name;
end
end