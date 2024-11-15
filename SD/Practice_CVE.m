clc; clear; close all;

%% 설정
lambda_values = logspace(-4, 9, 5);
tau_min = 0.1;

%% 데이터 로드
save_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_lambda\';
file_path = 'G:\공유 드라이브\Battery Software Lab\Projects\DRT\SD_new\';
mat_files = dir(fullfile(file_path, '*.mat'));
if isempty(mat_files)
    error('데이터 파일이 존재하지 않습니다. 경로를 확인해주세요.');
end
for file = mat_files'
    load(fullfile(file_path, file.name));
end

%% 데이터셋 선택
datasets = {'AS1_1per_new', 'AS1_2per_new', 'AS2_1per_new', 'AS2_2per_new'};
disp('데이터셋을 선택하세요:');
for i = 1:length(datasets)
    fprintf('%d. %s\n', i, datasets{i});
end
dataset_idx = input('데이터셋 번호를 입력하세요: ');
if isempty(dataset_idx) || dataset_idx < 1 || dataset_idx > length(datasets)
    error('유효한 데이터셋 번호를 입력해주세요.');
end
selected_dataset_name = datasets{dataset_idx};
if ~exist(selected_dataset_name, 'var')
    error('선택한 데이터셋이 로드되지 않았습니다.');
end
selected_dataset = eval(selected_dataset_name);

%% 타입 선택 및 데이터 준비
types = unique({selected_dataset.type});
disp('타입을 선택하세요:');
for i = 1:length(types)
    fprintf('%d. %s\n', i, types{i});
end
type_idx = input('타입 번호를 입력하세요: ');
if isempty(type_idx) || type_idx < 1 || type_idx > length(types)
    error('유효한 타입 번호를 입력해주세요.');
end
selected_type = types{type_idx};
type_indices = strcmp({selected_dataset.type}, selected_type);
type_data = selected_dataset(type_indices);
if isempty(type_data)
    error('선택한 타입에 해당하는 데이터가 없습니다.');
end
SN_list = [type_data.SN];

%% 새로운 필드 추가 
new_fields = {'Lambda_vec', 'CVE', 'Lambda_hat'};
num_elements = length(selected_dataset);
empty_fields = repmat({[]}, 1, num_elements);

for nf = 1:length(new_fields)
    field_name = new_fields{nf};
    if ~isfield(selected_dataset, field_name)
        [selected_dataset.(field_name)] = empty_fields{:};
    end
end









