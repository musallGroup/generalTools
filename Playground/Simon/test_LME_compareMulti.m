%% test_LME_compareMulti

rng(42);
nAnimals   = 5;
nPerAnimal = 10;

animalID = repmat((1:nAnimals)', nPerAnimal, 1);
animalFX = randn(nAnimals, 1) * 2;

fprintf('=== Test 1: covariate balanced across conditions (should not change result) ===\n');
% SNR is the same distribution for both conditions -> not confounded
snr   = randn(nAnimals*nPerAnimal, 1) * 3 + 10;
cond1 = animalFX(animalID) + 0.5*snr + randn(nAnimals*nPerAnimal, 1);
cond2 = animalFX(animalID) + 0.5*snr + randn(nAnimals*nPerAnimal, 1) + 1;  % true effect = +1

dataIn      = [cond1; cond2];
conditionID = [ones(numel(cond1),1); 2*ones(numel(cond2),1)];
randomVar   = [animalID; animalID];
snrAll      = [snr; snr];

[pVal1, tStat1] = LME_compareMulti(dataIn, conditionID, randomVar);
[pVal2, tStat2] = LME_compareMulti(dataIn, conditionID, randomVar, [], [], snrAll);
fprintf('Without covariate: t = %6.3f, p = %.4f\n', tStat1, pVal1);
fprintf('With covariate:    t = %6.3f, p = %.4f\n', tStat2, pVal2);
fprintf('Expected: both significant, similar t-stats\n\n');

fprintf('=== Test 2: covariate confounded with condition (covariate should remove spurious effect) ===\n');
% SNR is higher in condition 2, SNR drives outcome, NO true condition effect
snr1  = randn(nAnimals*nPerAnimal, 1) * 1 + 5;   % cond1: low SNR ~5
snr2  = randn(nAnimals*nPerAnimal, 1) * 1 + 15;  % cond2: high SNR ~15
cond1 = animalFX(animalID) + 2*snr1 + randn(nAnimals*nPerAnimal, 1);
cond2 = animalFX(animalID) + 2*snr2 + randn(nAnimals*nPerAnimal, 1);  % no condition effect

dataIn      = [cond1; cond2];
conditionID = [ones(numel(cond1),1); 2*ones(numel(cond2),1)];
randomVar   = [animalID; animalID];
snrAll      = [snr1; snr2];

[pVal1, tStat1] = LME_compareMulti(dataIn, conditionID, randomVar);
[pVal2, tStat2] = LME_compareMulti(dataIn, conditionID, randomVar, [], [], snrAll);
fprintf('Without covariate: t = %6.3f, p = %.4f\n', tStat1, pVal1);
fprintf('With covariate:    t = %6.3f, p = %.4f\n', tStat2, pVal2);
fprintf('Expected: significant WITHOUT covariate (spurious), not significant WITH covariate\n');
