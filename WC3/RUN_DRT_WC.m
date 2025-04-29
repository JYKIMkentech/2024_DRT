%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run_DRT_from_Results.m (2025‑04‑20)
% -------------------------------------------------------------------------
%  Input  : Results.mat  (Trip‑wise [V I t SOC]), plus OCV table
%  Output : gamma, R0, V_est, bootstrap 5–95 % bands, PNG & MAT files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% USER SETTINGS ----------------------------------------------------------
n            = 201;        % theta grid size
tau_max      = 1370;       % tau_max [s]
lambda_hat   = 0.05;       % regularisation
Q_batt_Ah    = 5;      % battery capacity [Ah]
num_bs       = 200;        % bootstrap repeats
outDir       = 'DRT_Figures';

if ~exist(outDir,'dir'), mkdir(outDir); end

%% 1) load data -----------------------------------------------------------
load('Results.mat','Results');

% OCV table (first cycle with non‑empty OCV field)
idxOCV     = find(~cellfun(@isempty,{Results.OCV}),1,'first');
soc_ocv    = Results(idxOCV).OCV;
soc_values = soc_ocv(:,1);
ocv_values = soc_ocv(:,2);

nCycles = numel(Results);

%% 2) preallocate containers ---------------------------------------------
gamma_single = {};
gamma_mean   = {};
gamma_low    = {};
gamma_high   = {};
R0_single    = {};
V_est_cell   = {};

%% 3) main loop -----------------------------------------------------------
for c = 1:nCycles
    cyc = Results(c).cycle_num;
    fprintf('=== Cycle %d (index %d/%d) ===\n',cyc,c,nCycles);

    tripIdx = 1;
    while true
        fld = sprintf('Trips_%d',tripIdx);
        if ~isfield(Results(c),fld) || isempty(Results(c).(fld)), break; end

        T  = Results(c).(fld);          % [V I t SOC]
        V  = T(:,1); I = T(:,2); t = T(:,3); SOC = T(:,4);

        fprintf('  > Trip %d (N = %d)\n',tripIdx,numel(t));

        % ------- single DRT ---------------------------------------------
        [gamma_hat,R0_hat,V_est] = DRT_estimation_aug( ...
            t,I,V,lambda_hat,n,tau_max,SOC,soc_values,ocv_values);

        % ------- bootstrap ---------------------------------------------
        SOC_begin = SOC(1);
        gamma_bs  = bootstrap_uncertainty_aug_FromResults( ...
            t,I,V,lambda_hat,n,tau_max,num_bs,SOC_begin,Q_batt_Ah, ...
            soc_values,ocv_values);

        g_mean = mean(gamma_bs,1).';
        g_low  = prctile(gamma_bs,  5,1).';
        g_high = prctile(gamma_bs,95,1).';

        % ------- store --------------------------------------------------
        gamma_single{c,tripIdx} = gamma_hat;
        gamma_mean{c,tripIdx}   = g_mean;
        gamma_low{c,tripIdx}    = g_low;
        gamma_high{c,tripIdx}   = g_high;
        R0_single{c,tripIdx}    = R0_hat;
        V_est_cell{c,tripIdx}   = V_est;

        % ------- voltage/current plot ----------------------------------
        fig = figure('Visible','off');
        yyaxis left
        plot(t,V,'k','LineWidth',1.2); hold on;
        plot(t,V_est,'--','LineWidth',1.2);
        ylabel('Voltage [V]');

        yyaxis right
        plot(t,I,'b','LineWidth',1);
        ylabel('Current [A]');
        title(sprintf('Cycle %d – Trip %d',cyc,tripIdx));
        grid on
        exportgraphics(fig, ...
            fullfile(outDir, ...
            sprintf('Volt_curr_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);
        close(fig);

        % ------- gamma(theta) plot -------------------------------------
        theta = linspace(log(0.1),log(tau_max),n).';
        fig = figure('Visible','off');
        fill([theta;flipud(theta)], ...
             [g_low;flipud(g_high)], ...
             [0.6 0.4 0.8],'FaceAlpha',0.2,'EdgeColor','none'); hold on;
        plot(theta,g_mean,'Color',[0.5 0 0.5],'LineWidth',2);
        xlabel('\theta = ln(\tau [s])');
        ylabel('\gamma [\Omega]');
        title(sprintf('\\gamma – Cycle %d, Trip %d',cyc,tripIdx));
        grid on
        exportgraphics(fig, ...
            fullfile(outDir, ...
            sprintf('Gamma_cyc%03d_trip%02d.png',cyc,tripIdx)), ...
            'Resolution',300);
        close(fig);

        tripIdx = tripIdx + 1;
    end
end

%% 4) save MAT files ------------------------------------------------------
save('DRT_gamma_single.mat','gamma_single','R0_single');
save('DRT_gamma_bootstrap.mat','gamma_mean','gamma_low','gamma_high');
disp('Run_DRT_from_Results: complete.');
