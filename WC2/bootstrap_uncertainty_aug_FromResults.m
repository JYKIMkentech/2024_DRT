function gamma_bs = bootstrap_uncertainty_aug_FromResults( ...
        t,ik,V_sd,lambda_hat,n,dur,num_resamples, ...
        SOC_begin,Q_batt_Ah,soc_values,ocv_values)
%BOOTSTRAP_UNCERTAINTY_AUG_FROMRESULTS  Monte‑Carlo bootstrap around
%DRT_estimation_aug. Returns a num_resamples×n matrix of gamma estimates.

N         = numel(t);
gamma_bs  = zeros(num_resamples,n);

for b = 1:num_resamples
    % --- resample with replacement --------------------------------------
    idx  = randsample(N,N,true);
    t_b  = t(idx);   ik_b = ik(idx);   V_b = V_sd(idx);

    % --- sort / unique time --------------------------------------------
    [t_u,iU] = unique(t_b);
    ik_u = ik_b(iU); V_u = V_b(iU);
    [t_s,iS] = sort(t_u);
    ik_s = ik_u(iS); V_s = V_u(iS);

    % --- SOC re‑integration --------------------------------------------
    SOC_s = SOC_begin + cumtrapz(t_s,ik_s)/(Q_batt_Ah*3600);

    % --- DRT estimate ---------------------------------------------------
    gamma_hat = DRT_estimation_aug( ...
        t_s,ik_s,V_s,lambda_hat,n,dur,SOC_s,soc_values,ocv_values);

    gamma_bs(b,:) = gamma_hat.';
end
end
