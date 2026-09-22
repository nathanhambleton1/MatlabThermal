%% Battery parameters

%% ModuleBot
ModuleBot.SOC_vecCell = [0, .1, .25, .5, .75, .9, 1]; % Vector of state-of-charge values, SOC
ModuleBot.T_vecCell = [278, 293, 313]; % Vector of temperatures, T, K
ModuleBot.V0_matCell = [3.49, 3.5, 3.51; 3.55, 3.57, 3.56; 3.62, 3.63, 3.64; 3.71, 3.71, 3.72; 3.91, 3.93, 3.94; 4.07, 4.08, 4.08; 4.19, 4.19, 4.19]; % Open-circuit voltage, V0(SOC,T), V
ModuleBot.V_rangeCell = [0, inf]; % Terminal voltage operating range [Min Max], V
ModuleBot.R0_matCell = [.0117, .0085, .009; .011, .0085, .009; .0114, .0087, .0092; .0107, .0082, .0088; .0107, .0083, .0091; .0113, .0085, .0089; .0116, .0085, .0089]; % Terminal resistance, R0(SOC,T), Ohm
ModuleBot.AHCell = 27; % Cell capacity, AH, A*hr
ModuleBot.thermal_massCell = 100; % Thermal mass, J/K
ModuleBot.AmbientResistance = 25; % Cell level ambient thermal path resistance, K/W
ModuleBot.XminThermalResistance = 25; % Cell-level thermal path resistance at Xmin boundary, K/W
ModuleBot.InterCellThermalResistance = 1; % Inter-cell thermal path resistance, K/W
ModuleBot.InterParallelAssemblyThermalResistance = 1; % Inter-parallel assembly thermal path resistance, K/W
ModuleBot.InterCellRadiationArea = 1e-3; % Inter-cell radiation heat transfer area, m^2
ModuleBot.InterCellRadiationCoefficient = 1e-6; % Inter-cell radiation heat transfer coefficient, W/(K^4*m^2)
ModuleBot.InterParallelAssemblyRadiationArea = 1e-3; % Inter-parallel assembly area for radiation heat transfer, m^2
ModuleBot.InterParallelAssemblyRadiationCoefficient = 1e-6; % Inter-parallel assembly coefficient for radiation heat transfer, W/(K^4*m^2)

%% ParallelAssemblyType1
ParallelAssemblyType1.SOC_vecCell = [0, .1, .25, .5, .75, .9, 1]; % Vector of state-of-charge values, SOC
ParallelAssemblyType1.T_vecCell = [278, 293, 313]; % Vector of temperatures, T, K
ParallelAssemblyType1.V0_matCell = [3.49, 3.5, 3.51; 3.55, 3.57, 3.56; 3.62, 3.63, 3.64; 3.71, 3.71, 3.72; 3.91, 3.93, 3.94; 4.07, 4.08, 4.08; 4.19, 4.19, 4.19]; % Open-circuit voltage, V0(SOC,T), V
ParallelAssemblyType1.V_rangeCell = [0, inf]; % Terminal voltage operating range [Min Max], V
ParallelAssemblyType1.R0_matCell = [.0117, .0085, .009; .011, .0085, .009; .0114, .0087, .0092; .0107, .0082, .0088; .0107, .0083, .0091; .0113, .0085, .0089; .0116, .0085, .0089]; % Terminal resistance, R0(SOC,T), Ohm
ParallelAssemblyType1.AHCell = 27; % Cell capacity, AH, A*hr
ParallelAssemblyType1.thermal_massCell = 100; % Thermal mass, J/K
ParallelAssemblyType1.AmbientResistance = 25; % Cell level ambient thermal path resistance, K/W
ParallelAssemblyType1.XminThermalResistance = 25; % Cell-level thermal path resistance at Xmin boundary, K/W
ParallelAssemblyType1.InterCellThermalResistance = 1; % Inter-cell thermal path resistance, K/W
ParallelAssemblyType1.InterCellRadiationArea = 1e-3; % Inter-cell radiation heat transfer area, m^2
ParallelAssemblyType1.InterCellRadiationCoefficient = 1e-6; % Inter-cell radiation heat transfer coefficient, W/(K^4*m^2)
