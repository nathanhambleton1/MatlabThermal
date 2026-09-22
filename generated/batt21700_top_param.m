%% Battery parameters

%% ModuleTop
ModuleTop.SOC_vecCell = [0, .1, .25, .5, .75, .9, 1]; % Vector of state-of-charge values, SOC
ModuleTop.T_vecCell = [278, 293, 313]; % Vector of temperatures, T, K
ModuleTop.V0_matCell = [3.49, 3.5, 3.51; 3.55, 3.57, 3.56; 3.62, 3.63, 3.64; 3.71, 3.71, 3.72; 3.91, 3.93, 3.94; 4.07, 4.08, 4.08; 4.19, 4.19, 4.19]; % Open-circuit voltage, V0(SOC,T), V
ModuleTop.V_rangeCell = [0, inf]; % Terminal voltage operating range [Min Max], V
ModuleTop.R0_matCell = [.0117, .0085, .009; .011, .0085, .009; .0114, .0087, .0092; .0107, .0082, .0088; .0107, .0083, .0091; .0113, .0085, .0089; .0116, .0085, .0089]; % Terminal resistance, R0(SOC,T), Ohm
ModuleTop.AHCell = 27; % Cell capacity, AH, A*hr
ModuleTop.thermal_massCell = 100; % Thermal mass, J/K
ModuleTop.AmbientResistance = 25; % Cell level ambient thermal path resistance, K/W
ModuleTop.XmaxThermalResistance = 25; % Cell-level thermal path resistance at Xmax boundary, K/W
ModuleTop.InterCellThermalResistance = 1; % Inter-cell thermal path resistance, K/W
ModuleTop.InterParallelAssemblyThermalResistance = 1; % Inter-parallel assembly thermal path resistance, K/W
ModuleTop.InterCellRadiationArea = 1e-3; % Inter-cell radiation heat transfer area, m^2
ModuleTop.InterCellRadiationCoefficient = 1e-6; % Inter-cell radiation heat transfer coefficient, W/(K^4*m^2)
ModuleTop.InterParallelAssemblyRadiationArea = 1e-3; % Inter-parallel assembly area for radiation heat transfer, m^2
ModuleTop.InterParallelAssemblyRadiationCoefficient = 1e-6; % Inter-parallel assembly coefficient for radiation heat transfer, W/(K^4*m^2)

%% ParallelAssemblyType1
ParallelAssemblyType1.SOC_vecCell = [0, .1, .25, .5, .75, .9, 1]; % Vector of state-of-charge values, SOC
ParallelAssemblyType1.T_vecCell = [278, 293, 313]; % Vector of temperatures, T, K
ParallelAssemblyType1.V0_matCell = [3.49, 3.5, 3.51; 3.55, 3.57, 3.56; 3.62, 3.63, 3.64; 3.71, 3.71, 3.72; 3.91, 3.93, 3.94; 4.07, 4.08, 4.08; 4.19, 4.19, 4.19]; % Open-circuit voltage, V0(SOC,T), V
ParallelAssemblyType1.V_rangeCell = [0, inf]; % Terminal voltage operating range [Min Max], V
ParallelAssemblyType1.R0_matCell = [.0117, .0085, .009; .011, .0085, .009; .0114, .0087, .0092; .0107, .0082, .0088; .0107, .0083, .0091; .0113, .0085, .0089; .0116, .0085, .0089]; % Terminal resistance, R0(SOC,T), Ohm
ParallelAssemblyType1.AHCell = 27; % Cell capacity, AH, A*hr
ParallelAssemblyType1.thermal_massCell = 100; % Thermal mass, J/K
ParallelAssemblyType1.AmbientResistance = 25; % Cell level ambient thermal path resistance, K/W
ParallelAssemblyType1.XmaxThermalResistance = 25; % Cell-level thermal path resistance at Xmax boundary, K/W
ParallelAssemblyType1.InterCellThermalResistance = 1; % Inter-cell thermal path resistance, K/W
ParallelAssemblyType1.InterCellRadiationArea = 1e-3; % Inter-cell radiation heat transfer area, m^2
ParallelAssemblyType1.InterCellRadiationCoefficient = 1e-6; % Inter-cell radiation heat transfer coefficient, W/(K^4*m^2)
