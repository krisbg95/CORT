clear
clc

mdir = pwd();
%%% Load neuroimaging and covariate data 
%%% BRAF data seperately 
load(append(mdir,'\CENTAUR_data.mat')); 

%%% Load flag (for indexing missing data)
flag=extractfield(data,'flag');
flag=reshape(flag,10,[]);  
% flag(11,:) = ~arrayfun(@(data) isempty(data.Area1),data);

%%% Extract covariates data
gender=extractfield(data,'gender'); 
age=extractfield(data,'age');
TIV = str2double(string(extractfield(data,'TIV')));   
base = fieldnames(data);    
base = base(4); 
outcomes = fieldnames(data);    
outcomes = outcomes(4:6); 

modality = {"rs_FC1";5}; 
resultsconn = struct('Outcome',outcomes','rs_FC1',[]);

for i = 1:size(outcomes)
    outcome = outcomes{i};  
    clin = extractfield(data,outcome); 
    nbase = base{1};  
    mbase = extractfield(data,nbase); 
    modname = modality{1,1};   
    mask = ~isnan(clin);  
    mask = flag(modality{2,1},:) + mask==2; 
    %%% Extract connectivity data
    SC1=[];
    subj=1;
    name=[];  
    for z=1:length(data)
        if mask(z)==1 
            name(subj)=string(data(z).name);
            SC1(:,:,subj)=data(z).(modality{1,1});
            subj=subj+1;
        end
    end  
    if i==1; covName=['subj' 'gender' 'age' 'baseline'];  X=[ones(subj-1,1), gender(mask)', age(mask)',clin(mask)']; C=[0 0 0 1]; else
    covName=['subj' 'gender' 'age' 'baseline' 'outcome']; X=[ones(subj-1,1), gender(mask)', age(mask)', mbase(mask)',clin(mask)']; 
    C=[0 0 0 0 1]; end
    for ROI=1:84
        LME(ROI).xX.X=X(setdiff(1:(subj-1),0),:);
        LME(ROI).xX.name=covName;
        LME(ROI).y=squeeze(SC1(ROI,:,setdiff(1:(subj-1),0)))';
        LME(ROI).c=C;
        [h,F,p,dof, statsname, B]=conn_glm(LME(ROI).xX.X, LME(ROI).y, LME(ROI).c, [1]);
        p=2*min(p,1-p); %%% create two-tailed p value
        LME(ROI).p_FDR=conn_fdr(squeeze(p));    
        LME(ROI).Coefficient = h;  
        LME(ROI).Test_statistic = F;  
        LME(ROI).Effect_size = (F).^2./((F).^2 + dof); %%% formula from 10.1016/j.edurev.2010.12.001
        LME(ROI).Raw_Pvalue = p;
        %%% If loop to index connections below threshold  
        ptres = 0.05;
        if sum(LME(ROI).p_FDR <ptres)>0 
            signif{ROI} = 'YES'; 
        else 
            signif{ROI} = 'NO';
        end
    end 
    %%% Index for significant connections
    Index = find(contains(signif,'YES'));  
    if size(Index,2)>0  
        statistics = {'ROI1','ROI2','Tvalue','pvalue','effectsize','Coefficient','rawpvalue'};
        for u = 1:size(Index,2) 
            rows = find(LME(Index(1,u)).p_FDR<ptres); 
            if modname ~='SC1';rows = intersect(rows,Index);end  
            if size(rows)>0
               for v = 1:size(rows)
                   statistics(end+1,:) = {data(1).seed{Index(1,u)},data(1).seed{(rows(v,1))},LME(Index(1,u)).Test_statistic(rows(v,1)),LME(Index(1,u)).p_FDR(rows(v,1)),LME(Index(1,u)).Effect_size(rows(v,1)),LME(Index(1,u)).Coefficient(rows(v,1)),LME(Index(1,u)).Raw_Pvalue(rows(v,1))};
               end
            end
        end 
        statistics = cell2table(statistics(2:end,:),'VariableNames',statistics(1,:)); 
        if modname ~='SC1'&& size(statistics,1)>0;statistics = clean_duplicates(statistics);end 
        if size(statistics,1)>0;statistics.Properties.RowNames = append(outcome,"_",string(1:size(statistics,1)));else statistics = {'No significant results'};end
    else
        statistics = {'No significant results'};
    end  
    resultsconn(i).(modname) = statistics;
end 

modality = {"Volume1","Area1","Thickness1";8,9,10}; 
resultsmorph = struct('Outcome',outcomes','Volume1',[],'Area1',[],'Thickness1',[]);
clear LME;

for i = 1:size(outcomes)
    outcome = outcomes{i};  
    clin = extractfield(data,outcome); 
    nbase = base{1};  
    mbase = extractfield(data,nbase); 
    for j = 1:size(modality,2)  
        modname = modality{1,j};   
        mask = ~isnan(clin);  
        mask = flag(modality{2,j},:) + mask==2; 
        %%% Extract connectivity data
        SC1=[];
        subj=1;
        name=[];  
        for z=1:length(data)
            if mask(z)==1 
                name(subj)=string(data(z).name);
                SC1(:,:,subj)=data(z).(modality{1,j});
                subj=subj+1;
            end
        end
        
        if i==1; covName=['subj' 'gender' 'age' 'TIV' 'baseline']; X=[ones(subj-1,1), gender(mask)', age(mask)',TIV(mask)',clin(mask)']; C=[0 0 0 0 1];  else covName=['subj' 'gender' 'age' 'baseline' 'TIV' 'outcome']; X=[ones(subj-1,1), gender(mask)', age(mask)', mbase(mask)',TIV(mask)',clin(mask)']; C=[0 0 0 0 0 1]; end
        %%% to create GLM using the covariate and Conn data 
        LME.xX.X=X(setdiff(1:(subj-1),0),:); 
        LME.xX.name=covName; 
        LME.y=squeeze(SC1(:,:,setdiff(1:(subj-1),0)))'; 
        LME.c=C; 
        [h,F,p,dof, statsname, B]=conn_glm(LME.xX.X, LME.y, LME.c, [1]); 
        p=2*min(p,1-p); %%% create two-tailed p value 
        LME.p_FDR=conn_fdr(squeeze(p));    
        LME.Test_statistic = F;  
        LME.Coefficient = h; 
        LME.Effect_size = (F).^2./((F).^2 + dof); %%% formula from 10.1016/j.edurev.2010.12.001
        LME.Raw_Pvalue = p;  
        %%% If loop to index connections below threshold  
        for c=1:length(LME.p_FDR)
            if LME.p_FDR(c) <0.05
                signif{c} = 'YES';
            else
                signif{c} = 'NO';
            end
        end
        %%% Index for significant connections
        Index = find(contains(signif,'YES')); 
        if size(Index,2)>0  
            statistics = {'ROI','Tvalue','pvalue','effectsize','Coefficient','rawpvalue'}; 
            for u = 1:size(Index,2)  
                statistics(end+1,:) = {data(1).seed{Index(1,u)},LME.Test_statistic(Index(1,u)),LME.p_FDR(Index(1,u)),LME.Effect_size(Index(1,u)),LME.Coefficient(Index(1,u)),LME.Raw_Pvalue(Index(1,u))};
            end 
            statistics = cell2table(statistics(2:end,:),'VariableNames',statistics(1,:)); 
            if size(statistics,1)>0;statistics.Properties.RowNames = append(outcome,"_",string(1:size(statistics,1)));else statistics = {'No significant results'};end
        else 
            statistics = {'No significant results'};
        end 
        resultsmorph(i).(modname) = statistics;
    end
    
end

results = resultsconn;  
[results.Volume1] = deal(resultsmorph.Volume1); 
[results.Area1] = deal(resultsmorph.Area1); 
[results.Thickness1] = deal(resultsmorph.Thickness1); 

modalities = fieldnames(results);modalities=modalities(2:end);  

for i=1:size(modalities,1)     
    temp = {results.(modalities{i})};
    cond = arrayfun(@(results) istable(results.(modalities{i})),results)'; 
    temp = temp(cond)'; 
    combined.(modalities{i}) = vertcat(temp{:});  
    T = combined.(modalities{i}); 
    sheetn = append('Sheet_',(modalities{i}));
    if size(T,1)>0 ;writetable(T,'Results.xlsx','Sheet',i,'WriteRowNames',true,'WriteMode','append');else writematrix(T,'Results.xlsx','Sheet',i,'WriteMode','append');end
end

e = actxserver('Excel.Application'); 
ewb = e.Workbooks.Open(append(mdir,"/","Results.xlsx"));  

for i=1:size(modalities,1) 
    ewb.Worksheets.Item(i).Name = (modalities{i}); % # rename i sheet
    ewb.Save % # save to the same file
end

ewb.Close(false)
e.Quit