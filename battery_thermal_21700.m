function battery_thermal_21700
%BATTERY_THERMAL_21700  100s2p 21700 Li-ion pack, air-cooled transient thermal model.
%
%   Usage:   >> battery_thermal_21700
%
%   WHAT THIS DOES
%   --------------
%   1. Declares the pack topology with Simscape Battery "Battery Builder" objects
%      (batteryCell -> batteryParallelAssembly -> batteryModule ->
%       batteryModuleAssembly -> batteryPack).  This is the authoritative pack
%      description and is used for reporting.  It is skipped automatically if
%      Simscape Battery is not installed.
%   2. Auto-arranges all Ns*Np cells into the physical grid closest to a square.
%   3. Builds a lumped-capacitance thermal network directly on that grid: every
%      cell is its own node, every grid neighbour is conductively coupled, and
%      cells sharing a parallel assembly get an extra busbar coupling.  Cooling
%      is natural convection + linearised radiation to still ambient air only
%      (pack "floating in air").  Interior cells are shadowed by their
%      neighbours, so they lose less area to ambient and run hotter.
%   4. Runs a rest / CC-charge / rest / CC-discharge / rest cycle with a simple
%      OCV + temperature-dependent-R cell model, exact parallel current sharing,
%      ohmic heat and entropic (reversible) heat.
%   5. Pops up a scrubbable figure: top-down heat map of the cell grid with a
%      time slider + play button, alongside Tmin/Tmean/Tmax and pack current.
%
%   The transient solve is fully vectorised (sparse conductance matrix, explicit
%   Euler at dt = 1 s) so the whole ~2 h cycle for 200 cells runs in about a
%   second -- versus minutes of compile time for a 200-cell Simscape network.

clc; close all;

%% ========================= 1. PARAMETERS =========================
P.Ns   = 100;        % parallel assemblies in series
P.Np   = 2;          % cells per parallel assembly
P.Tamb = 25;         % ambient still-air temperature            [degC]
P.T0   = 25;         % initial cell temperature                 [degC]

% --- generic cylindrical 21700 NMC cell ---------------------------
P.D     = 21.55e-3;  % diameter                                 [m]
P.H     = 70.15e-3;  % height                                   [m]
P.mass  = 0.070;     % cell mass                                [kg]
P.cp    = 900;       % specific heat                            [J/kg/K]
P.Qnom  = 4.5;       % nominal capacity                         [Ah]
P.R25   = 0.022;     % DC internal resistance @ 25 degC         [ohm]
P.kR    = -0.012;    % relative dR/dT                           [1/K]
P.dUdT  = -0.12e-3;  % entropic coefficient                     [V/K]
P.Vmax  = 4.20;      % per-cell charge cutoff                   [V]
P.Vmin  = 2.80;      % per-cell discharge cutoff                [V]

% --- packaging / heat transfer ------------------------------------
P.pitch  = 23.0e-3;  % cell centre-to-centre spacing            [m]
P.hConv  = 6.0;      % natural convection coefficient           [W/m^2/K]
P.emis   = 0.85;     % surface emissivity (linearised radiation)
P.Gcc    = 0.020;    % grid-neighbour cell<->cell conductance   [W/K]
                     %   (air gap conduction + mutual radiation + holder;
                     %    ~0.01-0.03 W/K for a 1.5 mm air gap at 23 mm pitch)
P.Gpa    = 0.050;    % extra busbar coupling inside a P-assy    [W/K]
P.shadow = 0.15;     % lateral area blocked per touching neighbour

% --- duty cycle ---------------------------------------------------
P.soc0   = 0.15;     % starting state of charge
P.Cchg   = 1.0;      % charge C-rate
P.Cdis   = 2.0;      % discharge C-rate
P.dt     = 1.0;      % integration step                         [s]
P.rec    = 10;       % recording interval                       [s]
P.spread = 0.03;     % +/- cell-to-cell parameter spread

rng(7);              % reproducible cell spread

%% =============== 2. MODULE SPLIT + BATTERY BUILDER ===============
% Split the 100 series parallel-assemblies into the most square-ish set of
% identical modules (divisor of Ns closest to sqrt(Ns)).
div         = find(mod(P.Ns, 1:P.Ns) == 0);
[~, kk]     = min(abs(div - sqrt(P.Ns)));
P.nPaPerMod = div(kk);
P.nMod      = P.Ns / P.nPaPerMod;

fprintf('=== Pack: %ds%dp  (%d cells) ===\n', P.Ns, P.Np, P.Ns*P.Np);
fprintf('  %d modules x %ds%dp  (%d cells/module)\n', ...
        P.nMod, P.nPaPerMod, P.Np, P.nPaPerMod*P.Np);

packObj = tryBatteryBuilder(P);   %#ok<NASGU>

%% ===================== 3. PHYSICAL CELL GRID =====================
N = P.Ns * P.Np;
[nRow, nCol] = bestSquareGrid(N);

% Cell k (series-major, parallel-minor) -> serpentine slot in the grid so that
% electrically adjacent cells are also physically adjacent.
row = zeros(N,1); col = zeros(N,1);
for k = 1:N
    r = ceil(k / nCol);
    c = k - (r-1)*nCol;
    if mod(r,2) == 0, c = nCol + 1 - c; end
    row(k) = r;  col(k) = c;
end
paIdx  = repelem(transpose(1:P.Ns), P.Np);   % parallel-assembly index per cell
modIdx = ceil(paIdx / P.nPaPerMod);          % module index per cell

slotId = nan(nRow, nCol);                    % grid slot -> cell index
for k = 1:N, slotId(row(k), col(k)) = k; end

fprintf('  Grid: %d rows x %d cols (%d slots, %d empty)\n\n', ...
        nRow, nCol, nRow*nCol, nRow*nCol - N);

%% ================== 4. THERMAL NETWORK ASSEMBLY ==================
% Conductance edges: 4-neighbour grid coupling + intra-parallel-assembly busbar.
ii = []; jj = []; gg = [];
for r = 1:nRow
    for c = 1:nCol
        a = slotId(r,c);
        if isnan(a), continue; end
        if c < nCol
            b = slotId(r, c+1);
            if ~isnan(b), ii(end+1)=a; jj(end+1)=b; gg(end+1)=P.Gcc; end %#ok<AGROW>
        end
        if r < nRow
            b = slotId(r+1, c);
            if ~isnan(b), ii(end+1)=a; jj(end+1)=b; gg(end+1)=P.Gcc; end %#ok<AGROW>
        end
    end
end
Ggrid = sparse([ii jj], [jj ii], [gg gg], N, N);
nNb   = min(full(sum(Ggrid ~= 0, 2)), 4);    % occupied grid neighbours per cell

ii = []; jj = []; gg = [];
for s = 1:P.Ns                               % busbar links inside each P-assy
    cells = find(paIdx == s);
    for a = 1:numel(cells)-1
        for b = a+1:numel(cells)
            ii(end+1)=cells(a); jj(end+1)=cells(b); gg(end+1)=P.Gpa; %#ok<AGROW>
        end
    end
end
G = Ggrid + sparse([ii jj], [jj ii], [gg gg], N, N);   % symmetric conductance
L = spdiags(full(sum(G,2)), 0, N, N) - G;     % Laplacian: (L*T)_i = heat OUT [W]

% Ambient exchange area: both end caps always exposed, lateral area reduced by
% each neighbouring cell (shadowing / view-factor blockage).
A_lat = pi * P.D * P.H;
A_end = 2 * pi * P.D^2 / 4;
A_amb = A_end + A_lat .* max(0.15, 1 - P.shadow*nNb);

sigma = 5.670374e-8;
hRad  = 4 * P.emis * sigma * (P.Tamb + 273.15)^3;   % linearised radiation
hA    = (P.hConv + hRad) * A_amb;                   % [W/K] per cell to ambient
Cth   = P.mass * P.cp * ones(N,1);                  % [J/K] per cell

%% ================= 5. CELL MODEL + DUTY CYCLE RUN ================
Rcell = P.R25  * (1 + P.spread*(2*rand(N,1)-1));
Qcap  = P.Qnom * (1 + 0.5*P.spread*(2*rand(N,1)-1));
ocvF  = ocvInterpolant();

phases = struct( ...
    'name', {'Rest', 'CC charge', 'Rest', 'CC discharge', 'Rest'}, ...
    'C',    { 0,     -P.Cchg,      0,      P.Cdis,         0    }, ...
    'stop', {'time', 'socHi',     'time', 'socLo',        'time'}, ...
    'val',  { 60,     0.95,        600,    0.08,           1800 });

T    = P.T0   * ones(N,1);
soc  = P.soc0 * ones(N,1);
t    = 0;  tPhase = 0;  ip = 1;
maxT = 4*3600;

nRec = ceil(maxT/P.rec) + 4;
rec.t = zeros(1,nRec);  rec.T   = zeros(N,nRec);  rec.I     = zeros(1,nRec);
rec.V = zeros(1,nRec);  rec.soc = zeros(1,nRec);  rec.phase = ones(1,nRec);
m = 0;  nextRec = 0;

fprintf('Simulating...\n');
tic;
while ip <= numel(phases) && t <= maxT
    Ipack = phases(ip).C * P.Qnom * P.Np;        % pack current, + = discharge

    % --- electrical: exact parallel sharing inside each P-assembly ---
    R    = Rcell .* max(0.4, 1 + P.kR*(T - 25));
    ocv  = ocvF(soc);
    invR = 1 ./ R;
    sInv = accumarray(paIdx, invR,      [P.Ns 1]);
    sOcv = accumarray(paIdx, ocv.*invR, [P.Ns 1]);
    Vpa  = (sOcv - Ipack) ./ sInv;               % terminal V of each P-assembly
    Icel = (ocv - Vpa(paIdx)) .* invR;           % per-cell current, + = discharge
    Vterm = ocv - Icel.*R;

    % --- heat generation: ohmic + entropic ---
    Q = Icel.^2 .* R - Icel .* (T + 273.15) * P.dUdT;

    % --- record ---
    if t >= nextRec
        m = m + 1;
        rec.t(m)=t; rec.T(:,m)=T; rec.I(m)=Ipack; rec.V(m)=sum(Vpa);
        rec.soc(m)=mean(soc); rec.phase(m)=ip;
        nextRec = nextRec + P.rec;
    end

    % --- integrate ---
    T   = T + P.dt * (Q - L*T - hA.*(T - P.Tamb)) ./ Cth;
    soc = soc - Icel * P.dt ./ (3600 * Qcap);
    t   = t + P.dt;  tPhase = tPhase + P.dt;

    % --- phase transition ---
    switch phases(ip).stop
        case 'time',  done = tPhase >= phases(ip).val;
        case 'socHi', done = mean(soc) >= phases(ip).val || max(Vterm) >= P.Vmax;
        case 'socLo', done = mean(soc) <= phases(ip).val || min(Vterm) <= P.Vmin;
        otherwise,    done = true;
    end
    if done, ip = ip + 1; tPhase = 0; end
end
fprintf('  done in %.2f s wall clock (%d cells, %.0f s simulated)\n', toc, N, t);

v = 1:m;
rec.t=rec.t(v); rec.T=rec.T(:,v); rec.I=rec.I(v);
rec.V=rec.V(v); rec.soc=rec.soc(v); rec.phase=rec.phase(v);

fprintf('  Peak cell temperature   : %.1f degC\n', max(rec.T(:)));
fprintf('  Peak spread across pack : %.1f K\n\n', ...
        max(max(rec.T,[],1) - min(rec.T,[],1)));

%% ========================= 6. VIEWER ============================
geo.nRow = nRow; geo.nCol = nCol; geo.slotId = slotId; geo.modIdx = modIdx;
showScrubber(rec, geo, P, phases);

end % ===================== main function =========================


%% ---------------------------------------------------------------
function packObj = tryBatteryBuilder(P)
%TRYBATTERYBUILDER  Declare the pack with Simscape Battery Builder objects.
packObj = [];
if isempty(which('batteryCell'))
    fprintf('  (Simscape Battery not found - Battery Builder objects skipped)\n');
    return
end
try
    geom  = batteryCylindricalGeometry(simscape.Value(P.H,"m"), ...
                                       simscape.Value(P.D/2,"m"));
    cellO = batteryCell(geom, ...
                Mass     = simscape.Value(P.mass,"kg"), ...
                Capacity = simscape.Value(P.Qnom,"A*hr"), ...
                Energy   = simscape.Value(P.Qnom*3.6,"W*hr"), ...
                Name     = "Cell21700");
    for k = P.nMod:-1:1     % distinct objects: Battery Builder needs unique handles
        paO     = batteryParallelAssembly(cellO, P.Np, Topology="Square", ...
                                          Rows=1, Name="PA" + string(k));
        mods(k) = batteryModule(paO, P.nPaPerMod, Name="Module" + string(k));
    end
    maO     = batteryModuleAssembly(mods, CircuitConnection="Series", ...
                                    Name="ModuleAssembly");
    packObj = batteryPack(maO, Name="Pack100s2p");
    fprintf('  Battery Builder topology object created (%s)\n', class(packObj));
catch ME
    fprintf('  (Battery Builder objects unavailable: %s)\n', ME.message);
end
end


%% ---------------------------------------------------------------
function [rb, cb] = bestSquareGrid(n)
%BESTSQUAREGRID  Grid closest to a square that holds n cells (may leave gaps).
best = inf; rb = n; cb = 1;
for c = 1:n
    r = ceil(n/c);
    score = abs(r - c) + 0.5*(r*c - n);   % squareness first, then wasted slots
    if score < best, best = score; rb = r; cb = c; end
end
end


%% ---------------------------------------------------------------
function F = ocvInterpolant()
%OCVINTERPOLANT  Generic NMC 21700 open-circuit voltage vs SOC.
s = [0 .05 .10 .20 .30 .40 .50 .60 .70 .80 .90 .95 1.00];
v = [3.00 3.35 3.45 3.55 3.62 3.68 3.75 3.83 3.93 4.02 4.12 4.17 4.20];
F = griddedInterpolant(s, v, 'linear', 'nearest');
end


%% ---------------------------------------------------------------
function showScrubber(rec, geo, P, phases)
%SHOWSCRUBBER  Top-down cell-temperature map with a time slider.

nRec = numel(rec.t);
Tlo  = min(rec.T(:));  Thi = max(rec.T(:));
if Thi - Tlo < 1, Thi = Tlo + 1; end
occ  = ~isnan(geo.slotId);

fig = figure('Name', sprintf('%ds%dp 21700 pack - cell temperatures', P.Ns, P.Np), ...
             'Color','w', 'Position',[60 60 1260 680]);

% ---------- heat map ----------
axG = axes('Parent',fig, 'Position',[0.05 0.20 0.40 0.70]);
im  = imagesc(axG, nan(geo.nRow, geo.nCol), [Tlo Thi]);
set(im, 'AlphaData', occ);
axis(axG, 'image'); set(axG, 'XTick', [], 'YTick', [], 'Box','on');
try
    colormap(axG, turbo);
catch
    colormap(axG, jet);
end
cbar = colorbar(axG); cbar.Label.String = 'Cell temperature [\circC]';
hold(axG, 'on');

% module boundaries
modGrid = nan(geo.nRow, geo.nCol);
modGrid(occ) = geo.modIdx(geo.slotId(occ));
for r = 1:geo.nRow
    for c = 1:geo.nCol
        if c < geo.nCol && ~isnan(modGrid(r,c)) && ~isnan(modGrid(r,c+1)) ...
                && modGrid(r,c) ~= modGrid(r,c+1)
            plot(axG, [c+.5 c+.5], [r-.5 r+.5], 'k-', 'LineWidth', 1.6);
        end
        if r < geo.nRow && ~isnan(modGrid(r,c)) && ~isnan(modGrid(r+1,c)) ...
                && modGrid(r,c) ~= modGrid(r+1,c)
            plot(axG, [c-.5 c+.5], [r+.5 r+.5], 'k-', 'LineWidth', 1.6);
        end
    end
end
ttl = title(axG, '', 'FontWeight','normal');

% ---------- temperature traces ----------
axT = axes('Parent',fig, 'Position',[0.56 0.58 0.39 0.33]);
tmin = rec.t/60;
hMax = plot(axT, tmin, max(rec.T,[],1), 'r-', 'LineWidth',1.4); hold(axT,'on');
hAvg = plot(axT, tmin, mean(rec.T,1),   'k-', 'LineWidth',1.2);
hMin = plot(axT, tmin, min(rec.T,[],1), 'b-', 'LineWidth',1.4);
yline(axT, P.Tamb, ':', 'ambient', 'HandleVisibility','off');
grid(axT,'on'); ylabel(axT,'T [\circC]');
legend(axT, [hMax hAvg hMin], {'max','mean','min'}, ...
       'Location','northwest', 'Box','off');
title(axT, 'Pack cell temperature', 'FontWeight','normal');
curT = xline(axT, 0, 'Color',[.3 .3 .3], 'LineWidth',1.2, 'HandleVisibility','off');

% ---------- current / voltage ----------
axI = axes('Parent',fig, 'Position',[0.56 0.20 0.39 0.28]);
yyaxis(axI,'left');
plot(axI, tmin, rec.I, 'LineWidth',1.4);
ylabel(axI,'I [A]  (+ = discharge)');
yyaxis(axI,'right');
plot(axI, tmin, rec.V, 'LineWidth',1.2); ylabel(axI,'pack V');
grid(axI,'on'); xlabel(axI,'time [min]');
curI = xline(axI, 0, 'Color',[.3 .3 .3], 'LineWidth',1.2);

% ---------- controls ----------
sld = uicontrol(fig, 'Style','slider', 'Units','normalized', ...
                'Position',[0.05 0.10 0.40 0.030], ...
                'Min',1, 'Max',nRec, 'Value',1, ...
                'SliderStep',[1/max(1,nRec-1) 20/max(1,nRec-1)]);
btn = uicontrol(fig, 'Style','togglebutton', 'Units','normalized', ...
                'Position',[0.05 0.035 0.09 0.045], 'String','Play', ...
                'FontWeight','bold');
chk = uicontrol(fig, 'Style','checkbox', 'Units','normalized', ...
                'Position',[0.16 0.040 0.29 0.035], 'BackgroundColor','w', ...
                'String','Auto colour scale (per frame)', ...
                'Callback', @(~,~) draw(round(get(sld,'Value'))));
addlistener(sld, 'ContinuousValueChange', @(s,~) draw(round(get(s,'Value'))));
set(sld, 'Callback', @(s,~) draw(round(get(s,'Value'))));
set(btn, 'Callback', @playCB);

draw(1);

    function draw(k)
        k = max(1, min(nRec, k));
        Tk = nan(geo.nRow, geo.nCol);
        Tk(occ) = rec.T(geo.slotId(occ), k);
        set(im, 'CData', Tk);
        if get(chk,'Value')          % stretch colours over this frame only
            lo = min(rec.T(:,k)); hi = max(rec.T(:,k));
            if hi - lo < 0.05, hi = lo + 0.05; end
            set(axG, 'CLim', [lo hi]);
        else
            set(axG, 'CLim', [Tlo Thi]);
        end
        set(curT, 'Value', rec.t(k)/60);
        set(curI, 'Value', rec.t(k)/60);
        set(ttl, 'String', { ...
            sprintf('t = %.1f min   |   %s   |   SOC %.0f%%', ...
                    rec.t(k)/60, phases(rec.phase(k)).name, 100*rec.soc(k)), ...
            sprintf('T  min %.1f / mean %.1f / max %.1f \\circC', ...
                    min(rec.T(:,k)), mean(rec.T(:,k)), max(rec.T(:,k)))});
        drawnow limitrate;
    end

    function playCB(src, ~)
        if get(src,'Value') == 1
            set(src, 'String', 'Pause');
            k = round(get(sld,'Value'));
            while isvalid(src) && get(src,'Value') == 1 && isvalid(fig)
                k = k + 1; if k > nRec, k = 1; end
                set(sld, 'Value', k); draw(k); pause(0.02);
            end
            if isvalid(src), set(src, 'String', 'Play'); end
        else
            set(src, 'String', 'Play');
        end
    end
end
