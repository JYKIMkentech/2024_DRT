clc; clear; close all;

data = readtable('G:\공유 드라이브\BSL_WC\Publishing_data_aging_summary_cell_059.csv', ...
                 'VariableNamingRule','preserve');

data.Properties.VariableNames{2} = 'ChargeCap';
data.Properties.VariableNames{3} = 'DischargeCap';
data.Properties.VariableNames{4} = 'CumulativeCap';

%% plot
figure('Color','w');
plot(data.Cycle, data.ChargeCap, 'o-', 'LineWidth',1.5); hold on;
plot(data.Cycle, data.DischargeCap, 'o-', 'LineWidth',1.5);
%plot(data.Cycle, data.CumulativeCap, 'o-', 'LineWidth',1.5);
xlabel('Cycle','FontWeight','bold','FontSize',12);
ylabel('Capacity','FontWeight','bold','FontSize',12);
legend({'ChargeCap','DischargeCap','CumulativeCap'}, 'Location','best');
title('Capacity vs. Cycle','FontWeight','bold','FontSize',14);
grid on;
