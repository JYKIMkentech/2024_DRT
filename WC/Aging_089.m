clc; clear; close all;

% 1. CSV 파일 불러오기 (원본 열 이름 그대로 읽어옴)
data = readtable('G:\공유 드라이브\BSL_WC\Publishing_data_aging_summary_cell_059.csv', ...
                 'VariableNamingRule','preserve');

% 2. 현재 열 이름 확인 (화면에 출력됨)
disp('현재 열 이름:');
disp(data.Properties.VariableNames);

% 3. 인덱스를 이용해 열 이름 변경
%    (1번 열은 'Cycle'로 이미 적절하다고 가정)
data.Properties.VariableNames{2} = 'ChargeCap';
data.Properties.VariableNames{3} = 'DischargeCap';
data.Properties.VariableNames{4} = 'CumulativeCap';

% 4. 변경된 열 이름 확인
disp('변경 후 열 이름:');
disp(data.Properties.VariableNames);

% 5. 플롯 그리기
figure('Color','w');
plot(data.Cycle, data.ChargeCap, 'o-', 'LineWidth',1.5); hold on;
plot(data.Cycle, data.DischargeCap, 'o-', 'LineWidth',1.5);
%plot(data.Cycle, data.CumulativeCap, 'o-', 'LineWidth',1.5);
xlabel('Cycle','FontWeight','bold','FontSize',12);
ylabel('Capacity','FontWeight','bold','FontSize',12);
legend({'ChargeCap','DischargeCap','CumulativeCap'}, 'Location','best');
title('Capacity vs. Cycle','FontWeight','bold','FontSize',14);
grid on;
