% Record
% Success
% Angle 1: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
% Angle 2: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
% Angle 3: 1, 2, 3, 4 ,5, 6, 7, 8, 9, 10

% Input values to determine video file to be used.
angle = 1;
vid = 10;

% Strings
file_path_vid = "./TestVideos/";
mp4 = ".mp4";
file_path_annot = "./Annotation/";
csv = ".csv";

% Names of files
files_angle1 = ["CAM1-GOPR0333-21157", "CAM1-GOPR0333-25390", "CAM1-GOPR0333-28114", "CAM1-GOPR0333-31464", "CAM1-GOPR0333-34217", "CAM1-GOPR0334-6600", "CAM1-GOPR0334-14238", "CAM1-GOPR0334-16875", "CAM1-GOPR0334-26813", "CAM1-GOPR0334-36441"];
files_angle2 = ["CAM2-GOPR0288-21180", "CAM2-GOPR0288-25413", "CAM2-GOPR0288-28137", "CAM2-GOPR0288-31487", "CAM2-GOPR0288-34240", "CAM2-GOPR0289-6563", "CAM2-GOPR0289-14201", "CAM2-GOPR0289-16838", "CAM2-GOPR0289-26776", "CAM2-GOPR0289-36404"];
files_angle3 = ["CAM3-GOPR0342-21108", "CAM3-GOPR0342-25341", "CAM3-GOPR0342-28065", "CAM3-GOPR0342-31415", "CAM3-GOPR0342-34168", "CAM3-GOPR0343-6479", "CAM3-GOPR0343-14117", "CAM3-GOPR0343-16754", "CAM3-GOPR0343-26692", "CAM3-GOPR0343-36320"];
files = [files_angle1; files_angle2; files_angle3];

% Read in the video file
pingpong = VideoReader(strcat(file_path_vid, files(angle, vid), mp4));

% Read in annotation csv
annotated_csv = csvread(strcat(file_path_annot, files(angle, vid), csv), 1, 0);

% Get background of video
% We do so by averaging away the foreground (moving objects)

% Firstly, we create a new matrix to store the color values of each pixel
background = struct('cdata',zeros(pingpong.Height,pingpong.Width,3,'uint8'),'colormap',[]);
mov = struct('cdata', zeros(pingpong.Height,pingpong.Width,3,'uint8'), 'colormap', []);

% Then we iterate through each frame (and all pixels) so that we get a
% running average as given by the formula in L5Color#33
k = 1;
while hasFrame(pingpong)
    mov(k).cdata = readFrame(pingpong);
    background.cdata = ((k-1)/k) .* background.cdata + (1/k) .* mov(k).cdata;
    k = k + 1;
end
num_frames = k - 1;
    
% extract foreground from every frame, change image into greyscale, store
% the new matrix into matrix called foreground
foreground = rgb2gray(mov(1).cdata - background.cdata);
for frame = 2:num_frames
    foreground(:,:,frame) = rgb2gray(mov(frame).cdata - background.cdata);
end
num_rows = size(foreground, 1);
num_cols = size(foreground, 2);

% Hard threshold by manual selection.
threshold_intensity_arr = [50, 50, 37];
threshold_intensity = threshold_intensity_arr(angle);
threshold_rec = zeros(1, num_frames);
% These values are used to eliminate noise from the calculated threshold
% and allow for continued tracking even when intensity of pixels fall drastically.
threshold_stability = [20 65 80];

% Search space initialisation- 50 by 100 matrix
% This is the window that we will be searching for the ball in.  
int_row_low = [290 285 250];
int_row_high = [340 335 300];
int_col_low = [525 570 1255];
int_col_high = [625 670 1355];

row_low = int_row_low(angle);
row_high = int_row_high(angle);
col_low = int_col_low(angle);
col_high = int_col_high(angle);
max_possible_num_of_pixels = 50 * 100;

% Arrays that keep track of results for analysis. 
tracked_arr = zeros(num_frames, 3); 
num_no_ball = 0;
num_with_ball = 0;

figure;
% This is used to keep track of the previous displacement of the ball's
% centroid. The value is used whenever we lose track of the ball midway to
% ensure that window follows the ball. We assume that the ball will
% continue in its direction of motion. 
previous_displacements = zeros(1,2);

for frame = 1:size(foreground, 3)
    tracked_arr(frame, 1) = frame - 1;
    x_coord = zeros(1, max_possible_num_of_pixels);
    y_coord = zeros(1, max_possible_num_of_pixels);
    above_count = 0;
    sum_above_threshold = 0;
    % Collate info of all pixels that will has an intensity >= threshold
    for i = row_low:row_high
        for j = col_low:col_high
            i = min(i, num_rows);
            j = min(j, num_cols);
            if foreground(i,j,frame) >= threshold_intensity
                sum_above_threshold = sum_above_threshold + double(foreground(i, j, frame));
                above_count = above_count + 1;
                x_coord(above_count) = i;
                y_coord(above_count) = j;
            end 
        end
    end
    % There are no pixels in this window that are above the threshold. A
    % ball is NOT detected. We will skip this frame and move on to the
    % next.
    if above_count == 0
        tracked_arr(frame, 2) = 0;
        tracked_arr(frame, 3) = 0;
        num_no_ball = num_no_ball + 1;
        objectRegion = [col_low row_low col_high-col_low row_high-row_low];
        framePrint = insertShape(foreground(:,:,frame), 'Rectangle', objectRegion, 'Color', 'red');
        frame;

        imshow(framePrint);
        continue;
    end
    % Note: If we've reached here it means we've found the ball.
    num_with_ball = num_with_ball + 1;
    x_coord_sum = 0;
    y_coord_sum = 0;
    for i = 1:above_count
        x_coord_sum = x_coord_sum + x_coord(i);
        y_coord_sum = y_coord_sum + y_coord(i);
    end
    x_centroid_pos = ceil(x_coord_sum / above_count);
    y_centroid_pos = ceil(y_coord_sum / above_count);
    % Storing the x_centroid_pos and y_centroid_pos to tracked_arr for
    % debugging and analysis.
    tracked_arr(frame, 2) = y_centroid_pos;
    tracked_arr(frame, 3) = x_centroid_pos;
    
    % Moving the window.
    if num_with_ball >= 2
        if tracked_arr(frame-1,3) == 0 || tracked_arr(frame-1,2) == 0
            row_low = row_low + previous_displacements(1) + 20;
            col_low = col_low + previous_displacements(2) + 5;
            row_high = row_high + previous_displacements(1) + 20;
            col_high = col_high + previous_displacements(2) + 5;
        else
            x_displacement = x_centroid_pos - tracked_arr(frame-1, 3);
            y_displacement = (y_centroid_pos - tracked_arr(frame-1, 2));
            row_low = row_low + x_displacement;
            row_low = max(row_low, 1);
            row_high = row_high + x_displacement;
            row_high = max(row_high, 1);
            col_low = col_low + y_displacement;
            col_low = max(col_low, 1);
            col_high = col_high + y_displacement ;
            col_high = max(col_high, 1); 
            previous_displacements = [x_displacement y_displacement];
        end
    end
    % Altering the threshold for the next frame. 
    threshold_intensity = max((sum_above_threshold / above_count) - threshold_stability(angle), threshold_intensity_arr(angle));
    threshold_rec(frame) = threshold_intensity;
    objectRegion = [col_low row_low col_high-col_low row_high-row_low];
    % Visualising the position of the ball in the frame. 
    frame;
    framePrint = insertMarker(mov(frame).cdata, [y_centroid_pos x_centroid_pos], '+', 'Color', 'red');
    framePrint = insertShape(framePrint, 'Rectangle', objectRegion, 'Color', 'red');
    imshow(framePrint);
end

% Values checking
% calculate 3 main variables:
% 1. points we annotated when there was no ball (wrong ball)
% 2. points we didn't annotate when there was a ball (missed ball)
% 3. average euclidean distance of the errors (when we identified a ball
% and there is indeed a ball)
num_wrong_ball = 0;
num_missed_ball = 0;
sum_euclidean_dist = 0;
num_correct_frames_marked = 0;
num_correct_frames_unmarked = 0;
for frame = 1:size(annotated_csv,1)
    if ((annotated_csv(frame, 2) == 0) && (annotated_csv(frame,3) == 0) && (tracked_arr(frame, 2) ~= 0) && (tracked_arr(frame,3) ~= 0))
        num_wrong_ball = num_wrong_ball + 1;
    elseif (annotated_csv(frame, 2) ~= 0) && (annotated_csv(frame,3) ~= 0) && (tracked_arr(frame, 2) == 0) && (tracked_arr(frame,3) == 0)
        num_missed_ball = num_missed_ball + 1;
    elseif (annotated_csv(frame, 2) == 0) && (annotated_csv(frame,3) == 0) && (tracked_arr(frame, 2) == 0) && (tracked_arr(frame,3) == 0)
        num_correct_frames_unmarked = num_correct_frames_unmarked + 1;
    else
        diff = sqrt((annotated_csv(frame,2) - tracked_arr(frame,2))^2 + (annotated_csv(frame,3) - tracked_arr(frame,3))^2);
        sum_euclidean_dist = sum_euclidean_dist + diff;
        num_correct_frames_marked = num_correct_frames_marked + 1;
    end
 end

disp(num_wrong_ball);
disp(num_missed_ball);
disp(num_correct_frames_unmarked);
disp(num_correct_frames_marked);
disp(sum_euclidean_dist / num_correct_frames_marked);