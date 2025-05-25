% plot_dt_vs_time.m
% -------------------------------------------------------------------------
% 각 cycle 및 trip별로 절대시간 t에 대한 Δt(diff(t))를 계산하여 플롯하고
% 결과를 이미지로 저장하는 스크립트
% -------------------------------------------------------------------------
clc; clear; close all;

%--- 1) 경로 설정 ----------------------------------------------------------
rootDir = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT';
preDir  = fullfile(rootDir,'PreResults');
dtDir   = fullfile(rootDir,'DRTResults','DT_Figures');
if ~exist(dtDir,'dir'), mkdir(dtDir); end

%--- 2) 데이터 로드 --------------------------------------------------------
load(fullfile(preDir,'Results.mat'),'Results');
nCycles = numel(Results);

%--- 3) 각 cycle·trip별 dt 계산 및 플롯 -------------------------------------
for c = 1:nCycles
    cyc = Results(c).cycle_num;
    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d', tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld))
            break;
        end
        T = Results(c).(fld);    % [V I t tRel SOC]
        t = T(:,3);              % 절대시간 벡터 [s]

        % dt 계산 및 길이 맞추기
        dt = diff(t);
        dt = [dt(1); dt];        % 첫 값 복제하여 벡터 길이 일치

        % 플롯 생성
        fig = figure('Visible','off');
        plot(t, dt, 'LineWidth',1.2);
        xlabel('Absolute time [s]');
        ylabel('\Delta t [s]');
        title(sprintf('Cycle %d – Trip %d: \\Delta t vs time',cyc,tripIdx), 'Interpreter','tex');
        grid on;

        % 그림 저장
        filename = sprintf('DT_cyc%03d_trip%02d.png',cyc,tripIdx);
        exportgraphics(fig, fullfile(dtDir,filename),'Resolution',300);
        close(fig);

        tripIdx = tripIdx + 1;
    end
end

fprintf('▶ 완료: 모든 cycle과 trip에 대해 dt 플롯 및 %s 저장 완료\n', dtDir);
