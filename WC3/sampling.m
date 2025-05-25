% plot_dt_vs_time.m
% -------------------------------------------------------------------------
% 각 cycle 및 trip별로 절대시간 t에 대한 Δt(diff(t))를 계산하여 플롯하고
% 결과를 이미지로 저장하는 스크립트
% -------------------------------------------------------------------------
clc; clear; close all;


%--- 2) 데이터 로드 --------------------------------------------------------
load('Results.mat');
nCycles = numel(Results);

%--- 3) 각 cycle·trip별 dt 계산 및 플롯 -------------------------------------
for c = 2 %:nCycles
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

        % 플롯 생성 (Visible on 으로 변경)
        figure('Visible','on');  % 또는 그냥 figure; 로만 쓰셔도 됩니다.
        plot(t, dt, 'LineWidth',1.2);
        xlabel('Absolute time [s]');
        ylabel('\Delta t [s]');
        title(sprintf('Cycle %d – Trip %d: \\Delta t vs time',cyc,tripIdx), 'Interpreter','tex');
        grid on;

        drawnow;   % 즉시 업데이트
        pause(0.5);% 각 플롯을 잠시 멈춰서 볼 수 있도록 (필요시 조정)

        tripIdx = tripIdx + 1;
    end
end

