# cs4243-pingpong
This is the code for a group project for CS4243 Computer Vision and Pattern Recognition.

For this project, the task was to track the flight of ping pong ball across the table across 3 angles of 10 videos each.

Along with my friend Low Jian Sheng, I am in charge of the ping pong ball tracking algorithm while 2 other group mates computed the depth of the ball and came up with the visualization software.

The crux of this algorithm is to use background reduction to identify the moving objects.

Thereafter, I've come up with the sliding window algorithm, whereby we place a small sliding window at where the ball is released in order to track it. This prevents noise (such as other bouncing ping pong balls) from skewing the calculation of the position of the desired ping pong ball.

In addition, I've also come up with the "catch-up" heuristic, whereby if the ball "disappeared" for a frame (as it has moved too fast), we will do some computations to "catch up" with the ball to continue the tracking.

This allows us to track approximately 93% of all videos.

Jian Sheng came up with another heuristic, the dynamic threshold heuristic, to allow us to capture the last 7% of videos.
