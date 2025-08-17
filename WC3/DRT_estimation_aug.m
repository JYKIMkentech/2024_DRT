function [gamma_est, R0_est, V_est, theta_discrete, W, y, OCV] = ...
    DRT_estimation_aug(t, ik, V_sd, lambda_hat, n, dt, dur, SOC, soc_values, ocv_values, anchorFirstSample)
% DRT_estimation_aug
% -------------------------------------------------------------------------
% • DRT(Distribution of Relaxation Times) 기반 전압 추정 + γ(θ), R0 추정
% • i(k-1)를 사용해 RC 누적항 z를 ZOH 가정으로 업데이트
% • J = ||(V - OCV) - [W, i]*[γ; R0]||^2 + λ||[L,0]*[γ;R0]||^2 최소화 (γ>=0, R0>=0)
% • 요청 2 반영: 첫 샘플에서 측정전압과 추정전압이 정확히 일치하도록 OCV를 앵커링
%
% Inputs
%   t            : 시간 벡터 (N×1)
%   ik           : 전류 벡터 (N×1)
%   V_sd         : 측정 전압 (N×1)
%   lambda_hat   : 정규화 계수 (스칼라)
%   n            : RC 이산 격자 개수
%   dt           : 샘플 간격 벡터 (N×1), dt(k)=t(k)-t(k-1)  (dt(1)은 사용 안 함)
%   dur          : τ_max [s]
%   SOC          : SOC 벡터 (N×1) — Trip의 5열
%   soc_values   : SOC–OCV 테이블의 SOC 열
%   ocv_values   : SOC–OCV 테이블의 OCV 열
%   anchorFirstSample (옵션, default=true)
%
% Outputs
%   gamma_est       : γ̂ (n×1)
%   R0_est          : R0̂ (스칼라)
%   V_est           : 추정 전압 (N×1)
%   theta_discrete  : θ 격자 (n×1), θ = ln(τ[s])
%   W               : 커널 행렬 (N×n)
%   y               : 타깃 (V - OCV) (N×1)
%   OCV             : (앵커링 반영된) OCV 벡터 (N×1)

    % ---- 옵션 기본값 ----------------------------------------------------
    if nargin < 11 || isempty(anchorFirstSample)
        anchorFirstSample = true;
    end

    % ---- 1) OCV: SOC–OCV 테이블 보간 -----------------------------------
    % 필요 시 SOC를 테이블 범위로 클램핑 (외삽 방지)
    soc_min = min(soc_values); soc_max = max(soc_values);
    SOC_for_OCV = min(max(SOC(:), soc_min), soc_max);
    OCV_lut = interp1(soc_values, ocv_values, SOC_for_OCV, 'linear', 'extrap');

    % ---- 1-1) 첫 샘플 앵커: OCV(1)=V(1) 되도록 상수 오프셋 --------------
    if anchorFirstSample
        delta = V_sd(1) - OCV_lut(1);
        OCV   = OCV_lut + delta;
    else
        OCV   = OCV_lut;
    end

    % ---- 2) θ, τ 격자 ---------------------------------------------------
    tau_min        = 0.1;                % [s]
    tau_max        = dur;                % [s]
    theta_discrete = linspace(log(tau_min), log(tau_max), n)';  % [n×1]
    delta_theta    = theta_discrete(2) - theta_discrete(1);
    tau_discrete   = exp(theta_discrete);                       % [n×1]

    % ---- 3) 커널 행렬 W (i(k-1) 사용, 첫 행 0) -------------------------
    N = length(t);
    W = zeros(N, n);
    ik = ik(:); V_sd = V_sd(:); dt = dt(:); OCV = OCV(:);

    for k = 2:N
        a = exp(-dt(k) ./ tau_discrete');                 % 1×n
        W(k, :) = W(k-1, :) .* a ...
                + ik(k-1) * (1 - a) * delta_theta;        % 1×n
    end

    % ---- 4) 오믹 항 보강: 첫 샘플 0으로 고정해 앵커 유지 ----------------
    ik_aug = ik;
    if anchorFirstSample
        ik_aug(1) = 0;
    end
    W_aug = [W, ik_aug];                                  % [N×(n+1)]

    % ---- 5) 타깃 y ------------------------------------------------------
    y = V_sd - OCV;                                       % [N×1]

    % ---- 6) 정규화 행렬 L (1차 차분), R0에는 정규화 X -------------------
    I_n = eye(n);
    L   = I_n(2:end,:) - I_n(1:end-1,:);
    L_aug = [L, zeros(n-1,1)];                            % [(n-1)×(n+1)]

    % ---- 7) QP 설정 -----------------------------------------------------
    H = 2 * (W_aug' * W_aug + lambda_hat * (L_aug' * L_aug));
    f = -2 * (W_aug' * y);
    A_ineq = -eye(n+1);
    b_ineq = zeros(n+1,1);

    options = optimoptions('quadprog','Display','off');
    params  = quadprog(H, f, A_ineq, b_ineq, [], [], [], [], [], options);

    % ---- 8) 결과 --------------------------------------------------------
    gamma_est = params(1:end-1);
    R0_est    = params(end);
    V_est     = OCV + W_aug * params;                     % 추정 전압
end

