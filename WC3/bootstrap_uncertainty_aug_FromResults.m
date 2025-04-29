%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bootstrap_uncertainty_aug_FromResults.m
% -------------------------------------------------------------------------
% γ(τ) 부트스트랩 불확실도 평가 (Trip 데이터를 복원추출 resample)
%
% gamma_bs = bootstrap_uncertainty_aug_FromResults( ...
%                   t, ik, V_sd, lambda_hat, n, dur, ...
%                   num_resamples, SOC_begin, Q_batt_Ah, ...
%                   soc_values, ocv_values )
%
% Output
%   gamma_bs  : (num_resamples × n) 행렬 – 각 행이 한 번의 γ estimate
% -------------------------------------------------------------------------
% 2025‑04‑20  JY Kim
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function gamma_bs = bootstrap_uncertainty_aug_FromResults( ...
            t, ik, V_sd, lambda_hat, n, dur, ...
            num_resamples, SOC_begin, Q_batt_Ah, ...
            soc_values, ocv_values)

    N  = numel(t);
    gamma_bs = zeros(num_resamples, n);

    for b = 1:num_resamples
        %% 1) 복원추출 인덱스 ------------------------------------------------
        idx = randsample(N, N, true);

        t_b   = t(idx);    ik_b  = ik(idx);   V_b = V_sd(idx);

        %% 2) 정렬 • unique -------------------------------------------------
        [t_u, iU] = unique(t_b);
        ik_u = ik_b(iU);   V_u = V_b(iU);
        [t_s, iS] = sort(t_u);
        ik_s = ik_u(iS);   V_s = V_u(iS);

        %% 3) SOC 재계산 ----------------------------------------------------
        SOC_s = SOC_begin + cumtrapz(t_s, ik_s)/(Q_batt_Ah*3600);

        %% 4) γ 추정 --------------------------------------------------------
        [gamma_hat, ~] = DRT_estimation_aug( ...
                t_s, ik_s, V_s, lambda_hat, n, dur, ...
                SOC_s, soc_values, ocv_values);

        gamma_bs(b,:) = gamma_hat.';
    end
end
