%% CV_lambda_from_Results.m  —  λ 교차검증 (Cycle 1, Trips 1–6)
% 2025‑04‑21 rev: 첫 번째 사이클(Results(1))의 Trips 1~6만 사용

clear; clc; close all;

%% 1) Results 및 OCV 읽기
load('Results.mat','Results');
soc_ocv    = Results(1).OCV;
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);

%% 2) 첫 번째 사이클의 Trip 데이터 수집
cycleData = Results(1);
maxTrip   = 6;
tripCells = cell(maxTrip,1);
for tIdx = 1:maxTrip
    fld = sprintf('Trips_%d', tIdx);
    if isfield(cycleData, fld)
        tripCells{tIdx} = cycleData.(fld);  % [V I t tRel SOC]
    else
        tripCells{tIdx} = [];
    end
end
% 유효(trip 데이터가 비어있지 않은) Trip 인덱스
validTrips = find(cellfun(@(x) ~isempty(x), tripCells));

%% 3) 파라미터 설정
n            = 201;                     % 분해능 파라미터
dur          = 20000;                    % [sec]
lambda_grids = logspace(-1.5,2,30);       % 후보 λ 그리드
num_lambdas  = numel(lambda_grids);

%% 4) Trip-level 교차검증 조합 생성 (인접한 쌍만)
% validTrips = [1,2,3,4,5,6]이라 가정
adj_pairs = [ validTrips(1:end-1), validTrips(2:end) ];
num_folds    = size(adj_pairs,1);
CVE_total    = zeros(num_lambdas,1);

%% 5) λ별 교차검증 수행
for m = 1:num_lambdas
    lambda = lambda_grids(m);
    CVE    = 0;

    for f = 1:num_folds
        val_trips   = adj_pairs(f,:);               
        train_trips = setdiff(validTrips, val_trips);  
        f
        % --- (이하 학습 및 검증 과정은 기존과 동일) ---
        % 1) 학습용 데이터 결합
        W_total = [];  y_total = [];
        for idx = train_trips
            T = tripCells{idx};
            V = T(:,1);  I = T(:,2);  t = T(:,4);  SOC = T(:,5);
            [~,~,~,~,~, W_aug, y, ~] = DRT_estimation_aug(t, I, V, ...
                lambda, n, dur, SOC, soc_values, ocv_values);
            W_total = [W_total; W_aug];
            y_total = [y_total; y];
        end

        % 2) γ, R0 추정
        [gamma_total, R0_total] = DRT_estimation_aug_with_Wy(W_total, y_total, lambda);

        % 3) 검증 세트 CVE 계산
        for idx = val_trips
            T = tripCells{idx};
            V = T(:,1);  I = T(:,2);  t = T(:,4);  SOC = T(:,5);
            [~,~,~,~,~, W_val, ~, OCV] = DRT_estimation_aug(t, I, V, ...
                lambda, n, dur, SOC, soc_values, ocv_values);
            V_est = OCV + W_val * [gamma_total; R0_total];
            CVE = CVE + sum((V - V_est).^2);
        end
    end

    CVE_total(m) = CVE;
    fprintf('Lambda: %.2e, CVE: %.4f\n', lambda, CVE);
end


%% 6) λ–CVE 결합 및 Results에 저장
% λ와 CVE를 묶은 n×2 행렬 생성
lambda_CVE = [ lambda_grids(:), CVE_total ];

% Results(1)에 새 필드로 추가
Results(1).lambda_CVE = lambda_CVE;

% .mat 파일에도 업데이트
save('Results.mat','Results','-append');

%% 7) 최적 λ 선택 및 플롯 (이전과 동일)
[~, idx_opt]   = min(CVE_total);
optimal_lambda = lambda_grids(idx_opt);

figure;
semilogx(lambda_grids, CVE_total, 'b-', 'LineWidth', 1.5); hold on;
semilogx(optimal_lambda, CVE_total(idx_opt), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('\lambda','FontSize',14);
ylabel('CVE','FontSize',14);
title('CVE vs \lambda (Cycle 1, Trips 1–6)','FontSize',16);
legend({'CVE', sprintf('Optimal \\lambda = %.2e', optimal_lambda)}, ...
       'Location','best','FontSize',12);
ylim([90.815 90.817]);
hold off;


%% 부록: γ, R₀ 추정 함수 정의
function [gamma_est, R0_est] = DRT_estimation_aug_with_Wy(W_total, y_total, lambda_hat)
    % W_total: [N×(n+1)], y_total: [N×1]
    Wn = size(W_total,2) - 1;  % gamma 파라미터 개수

    % 1차 차분 행렬 L
    L = spdiags([-ones(Wn,1) ones(Wn,1)],[0 1],Wn-1,Wn);
    L_aug = [L, sparse(Wn-1,1)];  % R0에 정규화 제외

    % 이차 최적화 문제 설정
    H = 2*(W_total'*W_total + lambda_hat*(L_aug'*L_aug));
    f = -2*(W_total'*y_total);

    % 비음수 제약
    A = -eye(Wn+1);
    b = zeros(Wn+1,1);

    opts = optimoptions('quadprog','Display','off');
    params = quadprog(H, f, A, b, [], [], [], [], [], opts);

    gamma_est = params(1:Wn);
    R0_est    = params(end);
end
