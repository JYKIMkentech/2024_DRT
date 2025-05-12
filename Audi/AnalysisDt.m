%% plot_dt_and_IV_all.m
% 저장된 ParseResultsNN.mat 파일을 불러와서
% ParseResults에 남아있는 모든 Trip에 대해
%   1) x축: 시간 t, y축: dt=[t(1); diff(t)] 플롯
%   2) yyaxis를 이용해 x축: 시간 t, 왼쪽 y축: 전류 I, 오른쪽 y축: 전압 V 플롯
% 자동으로 그립니다.

clc; clear; close all;

%% 1) 사용자 입력: Folder 번호
validFolders = [2 4 6 8 10 12 14 16];
folderNum = input('분석할 Folder 번호를 입력하세요 (예: 2): ');
if ~ismember(folderNum, validFolders)
    error('허용된 Folder 번호가 아닙니다.');
end

%% 2) ParseResults 파일 로드
basePath = 'G:\공유 드라이브\BSL_Audi\Drive';
matFile = fullfile(basePath, sprintf('Folder%d', folderNum), ...
                   sprintf('ParseResults%d.mat', folderNum));
if ~exist(matFile,'file')
    error('파일을 찾을 수 없습니다:\n%s', matFile);
end
S = load(matFile);
PR = S.ParseResults;  % struct with DrivingNum + TripN fields

%% 3) 남아있는 Trip 필드 자동 추출
allFields   = fieldnames(PR);
tripFields  = allFields(startsWith(allFields,'Trip'));

if isempty(tripFields)
    warning('ParseResults 안에 Trip 필드가 없습니다.');
    return;
end

fprintf('=== Folder %d: Plotting for %d Trip(s): %s ===\n', ...
        folderNum, numel(tripFields), strjoin(tripFields, ', '));

%% 4) 각 Trip에 대해 dt, I, V 계산 & 플롯 (dt: 마젠타, I: 파랑, V: 빨강)
for i = 1:numel(tripFields)
    fld = tripFields{i};
    data = PR.(fld);          
    if isempty(data), continue; end

    t   = data(:,3);         % 시간 [s]
    Vv  = data(:,1);         % 전압 [V]
    Iv  = data(:,2);         % 전류 [A]
    
    % dt 계산: diff(t) 첫 번째 값으로 시작
    dtd = diff(t);
    dt  = [dtd(1); dtd];

    % --- (a) dt vs t (dt: 마젠타) ---
    figure('Name', sprintf('Folder %d – %s: dt vs Time', folderNum, fld));
    plot(t, dt, 'm', 'LineWidth', 1.2);
    xlabel('Time [s]'); ylabel('dt [s]');
    title (sprintf('Folder %d – %s: dt vs Time', folderNum, fld));
    grid on;

    % --- (b) I & V vs t (I: 파랑, V: 빨강) ---
    figure('Name', sprintf('Folder %d – %s: I & V vs Time', folderNum, fld));
    yyaxis left
      plot(t, Iv, 'b', 'LineWidth', 1.2);
      ylabel('Current [A]');
    yyaxis right
      plot(t, Vv, 'r', 'LineWidth', 1.2);
      ylabel('Voltage [V]');
    xlabel('Time [s]');
    title (sprintf('Folder %d – %s: Current & Voltage vs Time', folderNum, fld));
    grid on;

    % --- (c) I & dt vs t (I: 파랑, dt: 마젠타) ---
    figure('Name', sprintf('Folder %d – %s: Current & dt vs Time', folderNum, fld));
    yyaxis left
      plot(t, Iv, 'b', 'LineWidth', 1.2);
      ylabel('Current [A]');
    yyaxis right
      plot(t, dt, 'm', 'LineWidth', 1.2);
      ylabel('dt [s]');
    xlabel('Time [s]');
    title (sprintf('Folder %d – %s: Current & dt vs Time', folderNum, fld));
    grid on;
end





