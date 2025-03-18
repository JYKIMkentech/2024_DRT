clc; clear; close all;

%% ========== (A) 셀 리스트 및 기본 경로 설정 ==========
cell_list = {'W3','W4','W5','W7','W8','W9','W10','G1','V4','V5'};
base_path = 'G:\공유 드라이브\BSL_Onori\Cycling_tests';

%% ========== (B) DRT_input 구조체 생성 (필드 순서 재정렬) ==========
%  아래처럼 원하는 순서대로 필드를 정의합니다.
%  - cycle_number 뒤에 Rest, Discharge
%  - TripN_Driving, TripN_DRT가 번갈아 보이도록
DRT_input = struct( ...
    'cell_name', {}, ...
    'cycle_number', {}, ...
    'Rest', {}, ...
    'Discharge', {}, ...
    'Trip1_Driving', {}, 'Trip1_DRT', {}, ...
    'Trip2_Driving', {}, 'Trip2_DRT', {}, ...
    'Trip3_Driving', {}, 'Trip3_DRT', {}, ...
    'Trip4_Driving', {}, 'Trip4_DRT', {}, ...
    'Trip5_Driving', {}, 'Trip5_DRT', {}, ...
    'Trip6_Driving', {}, 'Trip6_DRT', {}, ...
    'Trip7_Driving', {}, 'Trip7_DRT', {}, ...
    'Trip8_Driving', {}, 'Trip8_DRT', {}, ...
    'Trip9_Driving', {}, 'Trip9_DRT', {}, ...
    'Trip10_Driving', {}, 'Trip10_DRT', {}, ...
    'OCV', {}, 'Q_OCV', {}, 'Q_OPT', {}, ...
    'Driving_high_SOC', {}, 'DRT_high_SOC', {}, ...
    'Driving_mid_SOC',  {}, 'DRT_mid_SOC',  {}, ...
    'Driving_low_SOC',  {}, 'DRT_low_SOC',  {}, ...
    'DRT_feature', {}, 'SOH', {} );

count = 0;

% 최대 cycle 14까지 순회
for cycle_idx = 1:14
    folder_name = sprintf('Processed_%d', cycle_idx);
    folder_path = fullfile(base_path, folder_name);
    
    % 폴더 안의 *.mat 파일 목록
    mat_info = dir(fullfile(folder_path, '*.mat'));
    
    % 파일명(확장자 제외)만 추출
    mat_names_no_ext = cell(size(mat_info));
    for k = 1:numel(mat_info)
        [~, fname, ~] = fileparts(mat_info(k).name);
        mat_names_no_ext{k} = fname;
    end
    
    % cell_list와 교집합되는 파일(존재하는 셀)만 골라냄
    present_cells = intersect(cell_list, mat_names_no_ext);
    
    % 존재하는 셀마다 구조체 엔트리 생성
    for c = 1:numel(present_cells)
        count = count + 1;
        
        DRT_input(count).cell_name    = present_cells{c};
        DRT_input(count).cycle_number = cycle_idx;
        
        % Rest/Discharge 및 TripN_X 필드 모두 빈 배열로 초기화
        DRT_input(count).Rest       = [];
        DRT_input(count).Discharge  = [];
        
        for tnum = 1:10
            drvField = sprintf('Trip%d_Driving', tnum);
            drtField = sprintf('Trip%d_DRT',     tnum);
            DRT_input(count).(drvField) = [];
            DRT_input(count).(drtField) = [];
        end
        
        % 기타 필드도 빈 배열로 초기화
        DRT_input(count).OCV              = [];
        DRT_input(count).Q_OCV            = [];
        DRT_input(count).Q_OPT            = [];
        DRT_input(count).Driving_high_SOC = [];
        DRT_input(count).DRT_high_SOC     = [];
        DRT_input(count).Driving_mid_SOC  = [];
        DRT_input(count).DRT_mid_SOC      = [];
        DRT_input(count).Driving_low_SOC  = [];
        DRT_input(count).DRT_low_SOC      = [];
        DRT_input(count).DRT_feature      = [];
        DRT_input(count).SOH              = [];
    end
end

%% ========== (C) cell_list 순서 + cycle_number 순서로 정렬 ==========
all_cell_names = {DRT_input.cell_name};
all_cycles     = [DRT_input.cycle_number];

[~, idx_in_list] = ismember(all_cell_names, cell_list);
[~, sorted_idx]  = sortrows([idx_in_list(:), all_cycles(:)]);

DRT_input = DRT_input(sorted_idx);

%% ========== (D) 실제 파일 로드 및 UDDS 파싱 => Nx3 double로 변환해서 저장 ==========
for i = 1:length(DRT_input)
    cyc       = DRT_input(i).cycle_number;
    cell_name = DRT_input(i).cell_name;
    
    folder_name = sprintf('Processed_%d', cyc);
    mat_path    = fullfile(base_path, folder_name, sprintf('%s.mat', cell_name));
    
    if exist(mat_path, 'file')
        % (1) 파일 로드
        load(mat_path, '-mat');  
        %  예: t_full_vec_M1_NMC25degC, I_full_vec_M1_NMC25degC, V_full_vec_M1_NMC25degC, ...
        
        % (2) UDDS 파싱
        time = t_full_vec_M1_NMC25degC;
        curr = I_full_vec_M1_NMC25degC;
        volt = V_full_vec_M1_NMC25degC;
        step_arbi = Step_Index_full_vec_M1_NMC25degC;
        
        trips_parsed = parseUDDS(time, curr, volt, step_arbi);
        % => (N×1 struct): .t, .I, .V, .time_reset, .step 등
        
        % (3) Rest/Discharge = 맨 앞 2구간 (길이가 2개 미만이면 스킵)
        if length(trips_parsed) < 2
            continue;  % Rest/Discharge조차 없는 경우
        end
        
        % Rest, Discharge를 Nx3 double 형태로 저장
        rest_t = trips_parsed(1).t(:);
        rest_I = trips_parsed(1).I(:);
        rest_V = trips_parsed(1).V(:);
        DRT_input(i).Rest = [rest_t, rest_I, rest_V];
        
        dis_t = trips_parsed(2).t(:);
        dis_I = trips_parsed(2).I(:);
        dis_V = trips_parsed(2).V(:);
        DRT_input(i).Discharge = [dis_t, dis_I, dis_V];
        
        % (4) 3번째 구간부터는 실제 UDDS 여러 구간 => Trip1..Trip10
        if length(trips_parsed) < 3
            % UDDS가 없는 경우 (Rest/Discharge만 존재)
            continue;
        end
        subTrips = trips_parsed(3:end);  % 3번째부터 UDDS
        nSub = length(subTrips);
        
        maxTrips = 10;  % 최대 10개
        for j = 1:maxTrips
            drvField = sprintf('Trip%d_Driving', j);
            drtField = sprintf('Trip%d_DRT',     j);
            
            if j <= nSub
                t_j = subTrips(j).t(:);
                I_j = subTrips(j).I(:);
                V_j = subTrips(j).V(:);
                data_j = [t_j, I_j, V_j];
                
                DRT_input(i).(drvField) = data_j;
                DRT_input(i).(drtField) = data_j;  
                % 필요하다면 DRT 쪽에 다른 형태의 데이터를 저장해도 됨
            else
                DRT_input(i).(drvField) = [];
                DRT_input(i).(drtField) = [];
            end
        end
        
        % (추가) OCV, Q_OCV, Q_OPT 등 필요한 값을 계산해서 저장할 수도 있음
        % DRT_input(i).OCV = ...
        % ...
        
    else
        warning('파일이 존재하지 않습니다: %s', mat_path);
    end
end

%% ========== (E) 최종 DRT_input.mat로 저장 ==========
save_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\Stanford_DRT';
save(fullfile(save_path, 'DRT_input.mat'), 'DRT_input', '-v7.3');

disp('=== 모든 셀/사이클 파싱 완료 & DRT_input.mat 저장 완료 ===');


%% ========== (부록) UDDS 파싱 함수 (예시) ==========
function trips = parseUDDS(time, curr, volt, step_arbin)
    %{
      parseUDDS 함수: UDDS 파싱하여 trips라는 N×1 struct 배열을 반환
      각 요소: .t, .I, .V, .step, .time_reset 등
      아래 로직은 예시이며, 실제 배터리 step 구성에 맞춰 수정 가능
    %}
    data_raw.V    = volt;
    data_raw.I    = curr;
    data_raw.t    = time;
    data_raw.step = step_arbin;

    change_indices = [1; find(diff(step_arbin) ~= 0)+1; length(step_arbin)+1];
    num_segments   = length(change_indices) - 1;
    
    data_line = struct('V', [], 'I', [], 't', [], 'step', [], 'time_reset', []);
    data = repmat(data_line, num_segments, 1);
    
    for iSeg = 1:num_segments
        idx_start = change_indices(iSeg);
        idx_end   = change_indices(iSeg+1)-1;
        range     = idx_start:idx_end;
        
        data(iSeg).V    = data_raw.V(range);
        data(iSeg).I    = data_raw.I(range);
        data(iSeg).t    = data_raw.t(range);
        data(iSeg).step = data_raw.step(idx_start);
        data(iSeg).time_reset = data(iSeg).t - data(iSeg).t(1);
    end
    
    % 아래는 예시 로직: 14번 step과 그 바로 앞 2개 step => 총 3개를 trips_3로
    aging_cycle = 14;
    idx_step14 = find([data.step] == aging_cycle);
    if isempty(idx_step14)
        trips = data;
        return;
    end
    
    first_idx_14 = idx_step14(1);
    if first_idx_14 <= 2
        trips = data;
        return;
    end
    
    front_indices   = (first_idx_14 - 2) : (first_idx_14 - 1);
    desired_indices = [front_indices, first_idx_14];
    trips_3 = data(desired_indices);
    
    % (음의 피크 탐색 & 서브구간 분할) - 필요 시 수정
    t_total = vertcat(trips_3(:).t);
    I_total = vertcat(trips_3(:).I);
    
    minPeakHeight   = 4.0;
    minPeakDistance = 200;
    [negPeaks, locs] = findpeaks(-I_total, ...
        'MinPeakHeight',   minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
    negPeaks = -negPeaks;
    
    peakTimes  = t_total(locs);
    
    t_start_14 = trips_3(3).t(1);
    t_end_14   = trips_3(3).t(end);
    
    in14_mask    = (peakTimes >= t_start_14) & (peakTimes <= t_end_14);
    peakTimes_14 = peakTimes(in14_mask);
    numPeaks_14  = length(peakTimes_14);
    
    if numPeaks_14 < 2
        subTrips = trips_3(3);
    else
        odd_idx_14   = 1:2:numPeaks_14;
        odd_times_14 = peakTimes_14(odd_idx_14);
        
        timeDiffs_14_odd = diff(odd_times_14);
        boundaryTimes = t_start_14 + [0; cumsum(timeDiffs_14_odd)];
        if boundaryTimes(end) < t_end_14
            boundaryTimes(end+1) = t_end_14;
        end
        
        template_sub = trips_3(3);
        template_sub.V = [];
        template_sub.I = [];
        template_sub.t = [];
        template_sub.time_reset = [];
        
        num_subBound = length(boundaryTimes);
        subTrips = repmat(template_sub, num_subBound-1, 1);
        
        for iSub = 1:(num_subBound - 1)
            tStart = boundaryTimes(iSub);
            tEnd   = boundaryTimes(iSub+1);

            idxRange = (trips_3(3).t >= tStart) & (trips_3(3).t < tEnd);
            if iSub == (num_subBound - 1)
                idxRange = (trips_3(3).t >= tStart) & (trips_3(3).t <= tEnd);
            end
            
            subTrips(iSub).V = trips_3(3).V(idxRange);
            subTrips(iSub).I = trips_3(3).I(idxRange);
            subTrips(iSub).t = trips_3(3).t(idxRange);
            
            if ~isempty(subTrips(iSub).t)
                subTrips(iSub).time_reset = subTrips(iSub).t - subTrips(iSub).t(1);
            else
                subTrips(iSub).time_reset = [];
            end
        end
    end
    
    % 최종: rest(1), discharge(2), + subTrips(3) = UDDS 세분 구간들
    trips = [trips_3(1:2); subTrips];
end
