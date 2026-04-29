clc; clear; close all;

%% =========================================================
%  MAGNUS EFFECT BALL TRACKER
%  – Pixel-to-mm calibration via two-click diameter measure
%  – Manual click: ball center then spin marker each frame
%  – Raw clicked trajectory (no polynomial fitting)
%  – Average angular velocity + average linear velocity
%  – Saves all data for external analysis / theory comparison
% =========================================================

%% --- USER INPUT ---
folder      = 'data/f_straight1';
fps         = 500;            % camera frame rate (Hz)
first_frame = 6;
last_frame  = 33;

% Label for this run: 'No Spin' | 'CW Spin' | 'CCW Spin'
trial_label = 'f_straight1';

% Output .mat filename
save_file   = 'f_straight1.mat';

% Known ball diameter in mm
%ball_diameter_mm = 40;
ball_diameter_mm = 39;

% Number of frames for which to click BOTH center AND spin marker.
% After this, only the center is clicked (trajectory only).
spin_frames = 10;

% =========================================================
image_files = dir(fullfile(folder, '*.bmp'));
if isempty(image_files)
    error('No .bmp files found in folder: %s', folder);
end

num_frames  = last_frame - first_frame + 1;
centers_px  = nan(num_frames, 2);   % clicked centers [px]
angles_rad  = nan(num_frames, 1);   % marker angle from center [rad]
frame_times = ((0:num_frames-1) / fps)';   % time of each frame [s]

img_first = imread(fullfile(folder, image_files(first_frame).name));

%% =========================================================
%  STEP 1 – PIXEL-TO-MM CALIBRATION
%  Click two points on opposite edges of the ball.
% =========================================================
fprintf('\n==============================================\n');
fprintf('  STEP 1: Pixel-to-mm calibration\n');
fprintf('  Click two points on opposite edges of the\n');
fprintf('  ball (across a full diameter).\n');
fprintf('==============================================\n\n');

cal_confirmed = false;
while ~cal_confirmed

    fig_cal = figure('Name','Calibration – click across ball diameter', ...
                     'Units','normalized','OuterPosition',[0.1 0.1 0.8 0.8]);
    imshow(img_first); hold on;
    title(sprintf('[%s]  Calibration – click point 1 on one edge of the ball ...', ...
                  trial_label), 'FontSize',13,'FontWeight','bold');
    drawnow;

    [x1, y1] = ginput(1);
    plot(x1, y1, 'r+','MarkerSize',18,'LineWidth',2.5);
    plot(x1, y1, 'ro','MarkerSize',10,'LineWidth',2);
    title(sprintf('[%s]  Calibration – click point 2 on the OPPOSITE edge ...', ...
                  trial_label), 'FontSize',13,'FontWeight','bold');
    drawnow;

    [x2, y2] = ginput(1);
    plot(x2, y2, 'r+','MarkerSize',18,'LineWidth',2.5);
    plot(x2, y2, 'ro','MarkerSize',10,'LineWidth',2);

    line([x1 x2],[y1 y2],'Color','r','LineWidth',2,'LineStyle','--');
    dist_px   = sqrt((x2-x1)^2 + (y2-y1)^2);
    mm_per_px = ball_diameter_mm / dist_px;
    px_per_mm = dist_px / ball_diameter_mm;

    mid_x = (x1+x2)/2;  mid_y = (y1+y2)/2;
    text(mid_x, mid_y - 20, ...
         sprintf('%.1f px  =  %.0f mm\n(%.5f mm/px)', ...
                 dist_px, ball_diameter_mm, mm_per_px), ...
         'Color','y','FontSize',12,'FontWeight','bold', ...
         'HorizontalAlignment','center','BackgroundColor',[0 0 0 0.5]);
    drawnow;

    fprintf('  Measured diameter: %.2f px\n', dist_px);
    fprintf('  Scale:             %.5f mm/px  (%.2f px/mm)\n', mm_per_px, px_per_mm);

    ans_ = questdlg( ...
        sprintf('Diameter = %.1f px  →  %.5f mm/px\nDoes this look correct?', ...
                dist_px, mm_per_px), ...
        'Calibration Check','Yes – continue','No – redo','Yes – continue');
    if isempty(ans_), ans_ = 'Yes – continue'; end
    close(fig_cal);

    if strcmp(ans_,'Yes – continue')
        cal_confirmed = true;
        fprintf('  Calibration accepted.\n\n');
    else
        fprintf('  Redoing calibration ...\n\n');
    end
end

%% =========================================================
%  STEP 2 – FRAME-BY-FRAME MANUAL CLICKING
%  Full image shown each frame – no ROI needed.
%  Click 1: ball center   Click 2: spin marker
% =========================================================
spin_frames = min(spin_frames, num_frames);   % guard against out-of-range

fprintf('==============================================\n');
fprintf('  Trial: %s\n', trial_label);
fprintf('  Frames: %d to %d  (%d frames at %d fps)\n', ...
        first_frame, last_frame, num_frames, fps);
fprintf('  Frames  1 – %2d : click center then MARKER\n', spin_frames);
fprintf('  Frames %2d – %2d : click center only\n', spin_frames+1, num_frames);
fprintf('==============================================\n\n');

trackFig = figure('Name', sprintf('Ball Tracker – %s', trial_label), ...
                  'Units','normalized','OuterPosition',[0 0 1 1]);

for k = 1:num_frames
    frame_idx  = first_frame + k - 1;
    spin_phase = k <= spin_frames;   % true = click center + marker
    img = imread(fullfile(folder, image_files(frame_idx).name));

    figure(trackFig); clf;
    imshow(img); hold on;

    % Draw trajectory of previously clicked centers
    if k > 1
        prev = ~isnan(centers_px(1:k-1,1));
        if any(prev)
            plot(centers_px(prev,1), centers_px(prev,2), ...
                 'g.-','LineWidth',2,'MarkerSize',12);
        end
    end

    % Title changes depending on phase
    if spin_phase
        title_str = sprintf('[%s]  Frame %d  (%d / %d)  – SPIN PHASE\nClick 1: ball center   Click 2: spin MARKER', ...
                            trial_label, frame_idx, k, num_frames);
    else
        title_str = sprintf('[%s]  Frame %d  (%d / %d)  – TRAJECTORY ONLY\nClick: ball center', ...
                            trial_label, frame_idx, k, num_frames);
    end
    title(title_str, 'FontSize',13,'FontWeight','bold');
    drawnow;

    % --- Click 1: ball center (every frame) ---
    fprintf('Frame %d/%d – click center … ', k, num_frames);
    [cx, cy] = ginput(1);
    centers_px(k,:) = [cx cy];

    plot(cx, cy, 'b+','MarkerSize',16,'LineWidth',2.5);
    plot(cx, cy, 'bo','MarkerSize',10,'LineWidth',2);
    drawnow;

    % --- Click 2: spin marker (spin phase only) ---
    if spin_phase
        fprintf('click MARKER … ');
        [mx, my] = ginput(1);
        angles_rad(k) = atan2(my - cy, mx - cx);

        plot(mx, my, 'r*','MarkerSize',14,'LineWidth',2);
        line([cx mx],[cy my],'Color','r','LineWidth',1.5);
        drawnow; pause(0.15);
        fprintf('done  [spin %d/%d]\n', k, spin_frames);
    else
        fprintf('done\n');
    end
end

fprintf('\nAll frames clicked.\n\n');

%% =========================================================
%  STEP 3 – ANGULAR VELOCITY  (spin phase frames only)
%  Unwrap angles then fit a straight line; slope = avg omega.
% =========================================================

% All valid centers (used for trajectory)
valid_traj = ~isnan(centers_px(:,1));
t_v        = frame_times(valid_traj);
cx_v       = centers_px(valid_traj,1);
cy_v       = centers_px(valid_traj,2);

% Spin-phase only (first spin_frames frames, where marker was clicked)
valid_spin = ~isnan(angles_rad);
t_spin     = frame_times(valid_spin);
ang_v      = unwrap(angles_rad(valid_spin));

pa        = polyfit(t_spin, ang_v, 1);
omega_rad = pa(1);                        % rad/s
omega_dps = rad2deg(omega_rad);           % deg/s
omega_rpm = omega_rad * 60 / (2*pi);     % RPM

dt_spin    = diff(t_spin);
omega_inst = diff(ang_v) ./ dt_spin;     % instantaneous [rad/s]
t_omega    = t_spin(1:end-1) + dt_spin/2;

%% =========================================================
%  STEP 4 – LINEAR VELOCITY
%
%  (a) Velocity components from linear fit to position [mm]:
%      slope of x(t) = vx,  slope of y(t) = vy.
%      Resultant = sqrt(vx²+vy²).  Best single-number summary.
%
%  (b) Average scalar speed = total arc length / total time.
%      Slightly higher when path curves; captures true distance.
% =========================================================
cx_mm = cx_v * mm_per_px;    % convert to mm
cy_mm = cy_v * mm_per_px;

% (a) Linear fit velocity components
pvx      = polyfit(t_v, cx_mm, 1);
pvy      = polyfit(t_v, cy_mm, 1);
vx_mms   = pvx(1);                         % mm/s  horizontal
vy_mms   = pvy(1);                         % mm/s  vertical (+ = downward in image)
vmag_mms = sqrt(vx_mms^2 + vy_mms^2);     % mm/s  resultant
vmag_ms  = vmag_mms / 1000;               % m/s
vmag_kmh = vmag_ms  * 3.6;               % km/h

% (b) Arc-length average speed
dt_traj        = diff(t_v);
ds_mm          = sqrt(diff(cx_mm).^2 + diff(cy_mm).^2);
speed_inst_mms = ds_mm ./ dt_traj;        % mm/s at each midpoint
speed_inst_ms  = speed_inst_mms / 1000;
t_speed        = t_v(1:end-1) + dt_traj/2;

total_dist_mm  = sum(ds_mm);
total_time_s   = t_v(end) - t_v(1);
avg_speed_mms  = total_dist_mm / total_time_s;
avg_speed_ms   = avg_speed_mms / 1000;
avg_speed_kmh  = avg_speed_ms  * 3.6;

%% --- Print results ---
fprintf('========================================\n');
fprintf('  Trial:       %s\n', trial_label);
fprintf('  Frames used: %d / %d\n', sum(valid_traj), num_frames);
fprintf('  Calibration: %.5f mm/px  (%.0f mm ball = %.1f px)\n', ...
        mm_per_px, ball_diameter_mm, dist_px);
fprintf('\n  Angular velocity (average):\n');
fprintf('    %+9.3f  rad/s\n',  omega_rad);
fprintf('    %+9.2f  deg/s\n',  omega_dps);
fprintf('    %+9.2f  RPM\n',    omega_rpm);
fprintf('\n  Linear velocity:\n');
fprintf('    vx = %+8.2f mm/s  (horizontal)\n', vx_mms);
fprintf('    vy = %+8.2f mm/s  (vertical, + = downward)\n', vy_mms);
fprintf('    Resultant (linear fit):        %7.2f mm/s = %5.3f m/s = %5.2f km/h\n', ...
        vmag_mms, vmag_ms, vmag_kmh);
fprintf('    Average scalar speed (arc):    %7.2f mm/s = %5.3f m/s = %5.2f km/h\n', ...
        avg_speed_mms, avg_speed_ms, avg_speed_kmh);
fprintf('    Total distance: %.2f mm  over  %.5f s\n', total_dist_mm, total_time_s);
fprintf('========================================\n\n');

%% =========================================================
%  STEP 5 – SAVE (all raw data + derived quantities)
% =========================================================
results.label            = trial_label;
results.folder           = folder;
results.fps              = fps;
results.first_frame      = first_frame;
results.last_frame       = last_frame;
results.spin_frames      = spin_frames;
% Time
results.frame_times      = frame_times;   % full time vector [s]
results.t_valid          = t_v;           % time at clicked frames [s]
results.t_spin           = t_spin;        % time at spin-phase frames [s]
% Raw clicks (pixels)
results.centers_px       = centers_px;    % [num_frames x 2]  NaN where skipped
results.cx_v             = cx_v;          % valid centers x [px]
results.cy_v             = cy_v;          % valid centers y [px]
results.angles_rad       = angles_rad;    % raw marker angles [rad], NaN after spin phase
% Calibration
results.ball_diameter_mm = ball_diameter_mm;
results.mm_per_px        = mm_per_px;
results.px_per_mm        = px_per_mm;
results.cal_pt1          = [x1 y1];
results.cal_pt2          = [x2 y2];
results.cal_dist_px      = dist_px;
% Positions in mm (for theory comparison)
results.cx_mm            = cx_mm;
results.cy_mm            = cy_mm;
% Angular velocity (from spin phase only)
results.ang_unwrapped    = ang_v;         % unwrapped angle [rad]
results.omega_rad        = omega_rad;     % avg [rad/s]
results.omega_dps        = omega_dps;     % avg [deg/s]
results.omega_rpm        = omega_rpm;     % avg [RPM]
results.omega_inst       = omega_inst;    % instantaneous [rad/s]
results.t_omega          = t_omega;
% Linear velocity (from full trajectory)
results.vx_mms           = vx_mms;
results.vy_mms           = vy_mms;
results.vmag_mms         = vmag_mms;
results.vmag_ms          = vmag_ms;
results.vmag_kmh         = vmag_kmh;
results.avg_speed_mms    = avg_speed_mms;
results.avg_speed_ms     = avg_speed_ms;
results.avg_speed_kmh    = avg_speed_kmh;
results.total_dist_mm    = total_dist_mm;
results.speed_inst_mms   = speed_inst_mms;
results.speed_inst_ms    = speed_inst_ms;
results.t_speed          = t_speed;

save(save_file, 'results');
fprintf('Results saved to: %s\n\n', save_file);

%% =========================================================
%  STEP 6 – PLOTS
% =========================================================

% --- Raw trajectory on last frame ---
fig_traj = figure('Name', sprintf('Trajectory – %s', trial_label));
last_img  = imread(fullfile(folder, image_files(last_frame).name));
imshow(last_img); hold on;

plot(cx_v, cy_v, 'g.-','LineWidth',2,'MarkerSize',14,'DisplayName','Clicked centers');
plot(cx_v(1),   cy_v(1),   'go','MarkerSize',13,'LineWidth',2.5,'DisplayName','Start');
plot(cx_v(end), cy_v(end), 'rs','MarkerSize',13,'LineWidth',2.5,'DisplayName','End');
legend('Location','best','TextColor','w','Color',[0.2 0.2 0.2]);
title(sprintf('%s  |  \\omega = %+.1f RPM  |  v = %.2f m/s', ...
      trial_label, omega_rpm, vmag_ms), 'FontSize',13,'FontWeight','bold','Color','w');

% Save trajectory image
traj_filename = sprintf('trajectory_%s.png', strrep(trial_label,' ','_'));
exportgraphics(fig_traj, traj_filename, 'Resolution',300);
fprintf('Trajectory image saved to: %s\n\n', traj_filename);

% --- Three-panel analysis ---
figure('Name', sprintf('Analysis – %s', trial_label), ...
       'Units','normalized','OuterPosition',[0.05 0.05 0.9 0.9]);

subplot(3,1,1);
plot(t_spin, rad2deg(ang_v),'b.-','LineWidth',1.5,'MarkerSize',10); hold on;
plot(t_spin, rad2deg(polyval(pa,t_spin)),'r--','LineWidth',2);
xlabel('Time (s)'); ylabel('Unwrapped angle (°)');
title(sprintf('%s – spin angle vs time  (frames 1–%d)', trial_label, spin_frames));
legend('Measured','Linear fit (\omega_{avg})','Location','best'); grid on;

subplot(3,1,2);
plot(t_omega, rad2deg(omega_inst),'k.-','LineWidth',1.5,'MarkerSize',10); hold on;
yline(omega_dps,'r--','LineWidth',2, ...
      'Label',sprintf('%+.1f deg/s  |  %+.1f RPM', omega_dps, omega_rpm));
xlabel('Time (s)'); ylabel('\omega  (deg/s)');
title('Instantaneous angular velocity'); grid on;

subplot(3,1,3);
plot(t_speed, speed_inst_mms,'k.-','LineWidth',1.5,'MarkerSize',10); hold on;
yline(avg_speed_mms,'r--','LineWidth',2, ...
      'Label',sprintf('Avg  %.1f mm/s  (%.3f m/s)', avg_speed_mms, avg_speed_ms));
xlabel('Time (s)'); ylabel('Speed (mm/s)');
title(sprintf('Instantaneous linear speed  |  resultant %.3f m/s  =  %.2f km/h', ...
      vmag_ms, vmag_kmh));
grid on;

fprintf('Done.\n');