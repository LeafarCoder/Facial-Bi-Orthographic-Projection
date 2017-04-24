/* 

Skecth design and created by Rafael Correia (March 2017)

This sketch allows the merging of two images into one single points cloud.
We are able to distinguish both faces rotating the cloud and seeing each face individually.

Control keys:
1 - Toggle image 1
2 - Toggle image 2
R - Reset sketch
N - Align cloud to see image 1
M - Align cloud to see image 2

Mouse control:
Click left button and drag to rotate cloud.

Warnings: 
- Images with a similar width/height ratio are preferable.
- Images with good resolution give better results.
- If sketch is running slowly try to modify some lines of code down there (read comments)

*/


// Images related variables
PImage img_1, img_2;
PGraphics g1, g2;
PVector img_1_dim;
PVector img_2_dim;
int w, h;

// Camera related variables
PVector cam_1, cam_2, cam_3;
int rotate_state = 0;
float camera_rotate_inc = 0.2;
float camera_angle;
float old_camera_angle;

// Points cloud:
PVector[] points;

// Control variables
boolean show_img_1, show_img_2;
boolean img_turn;
boolean stop;

// Other variables...
int drag_mouse_x;
int frame_limit;
int sphere_radius = 8;
int current_point;
// sample of random spheres from which we pick a winning one
int sample_pool = 8;

// min_span and max_span are the that tell us the range in which we can draw a sphere in the z axis according to the sphere's x and y coordinate.
// This relates to prespective issues. 
int min_span, max_span;

// how far away the camera is from the center of the point cloud.
int focal_dist = 2000;


void setup() {
  // The images must be on the same directory as the skecth:
  // Images with a similar width/length ratio are preferable.
  img_1 = loadImage("obama_original.jpg");
  img_2 = loadImage("brad_pitt_original.jpg");
  
  size(800,700,P3D);
  frameRate(1000);
  
  initialize();
}

void initialize() {
  stop = false;
  img_turn = false;
  
  cam_1 = new PVector(0, 0, focal_dist);
  cam_2 = new PVector(focal_dist, 0, 0);
  cam_3 = new PVector(-focal_dist, 0, 0);
  rotate_state = 0;
  
  img_1_dim = new PVector(0,0);
  img_1_dim.x = img_1.width;
  img_1_dim.y = img_1.height;
  
  img_2_dim = new PVector(0,0);
  img_2_dim.x = img_2.width;
  img_2_dim.y = img_2.height;
  
  // setting up the images size to be the same by changing width/height ratio
  float r1 = (float)img_2_dim.x / img_1_dim.x;
  img_2_dim.x /= r1;
  img_2_dim.y /= r1;
  if(img_2_dim.y > img_1_dim.y){
    img_2_dim.y = img_1_dim.y;
  }else{
    img_1_dim.y = img_2_dim.y;
  }
  
  // w = both images width
  // h = both images height
  w = (int)img_1_dim.x;
  h = (int)img_1_dim.y;
  
  // prevents from drawing in some frame_limit from the edge;
  frame_limit = (int)(max(w,h)*0.01);
  
  min_span = - w / 2;
  max_span = w / 2;
  
  show_img_1 = false;
  show_img_2 = false;
  
  camera_angle = 0;
  
  g1 = createGraphics(w, h);
  g1.beginDraw();
  g1.tint(255,120);
  g1.image(img_1, 0, 0, w, h);
  g1.endDraw();
  
  g2 = createGraphics(w, h);
  g2.beginDraw();
  g2.tint(255,120);
  g2.image(img_2, 0, 0, w, h);
  g2.endDraw();
  
  // very hardly this will pose a problem but if some issue occurs try to increment "points" vector size
  points = new PVector[100000];
  current_point = 0;
}

void draw(){

  camera(focal_dist*sin(camera_angle), 0, focal_dist*cos(camera_angle), 0, 0, 0, 0, 1, 0);

  if(!stop){
    float min = 256 , gmc;
    int r_x, r_y, frx=0, fry=0, frz=0;
    
    for(int i=0; i < sample_pool; i++){
      // picking a random x and y coordinate
      r_x = (int)random(-w/2, w/2);
      r_y = (int)random(-h/2, h/2);
      
      // checking if coordinates are within boundary
      while(r_x < frame_limit - w/2 || r_x > w - frame_limit - w/2 || r_y < frame_limit - h/2 || r_y > h - frame_limit - h/2){
        r_x = (int)random(-w/2, w/2);
        r_y = (int)random(-h/2, h/2);
      }
      
      // get pixel color from the given coordinate
      gmc = getMeanColor(r_x + w/2, r_y + h/2, img_turn);
      // if this sphere is a better candidate relax point and keep searching
      if(gmc<min) {
        min = gmc;
        frx = r_x;
        fry = r_y;
      }
    }
    
    // Once the winning sphere is chosen we must compute its best z coordinate according to the other image
    
    /*
    That's what the following seemingly complicated lines of code are trying to do.
    It's a very simple idea, though the implementation might be a mess (I changed approach in the middle of the process and was to lazy 
    to rewrite all the code)
    Changing the z coordinate of the sphere won't change our perspective over the first image, and that's the beauty of the algorithm.
    */

    int r_x_, r_y_, r_z_ = 0;
    
    PVector gen_cam;
    
    if(img_turn){
      gen_cam = new PVector(cam_2.x, cam_2.y, cam_2.z);
    }else{
      gen_cam = new PVector(cam_3.x, cam_3.y, cam_3.z);
    }
    // decide frz in function of the other image
    PVector l1 = new PVector(frx, fry, 0);
    l1.sub(cam_1);
    l1.z *= -1;

    PVector l2 = new PVector(gen_cam.x, gen_cam.y, gen_cam.z);
    l2.sub(new PVector(0, 0, -w/2));
    l2.z *= -1;
    
    PVector l3 = new PVector(gen_cam.x, gen_cam.y, gen_cam.z);
    l3.sub(new PVector(0, 0, w/2));
    l3.z *= -1;
    
    if(!img_turn){
      l2.mult(-1);
      l3.mult(-1);
    }
    
    if(abs(l1.x) > 1){
      min_span = (int)-((l1.z/l1.x)*((w/2 + cam_1.z)/((l1.z/l1.x)-(l2.z/l2.x)))-cam_1.z);
      max_span = (int)-((l1.z/l1.x)*((-w/2 + cam_1.z)/((l1.z/l1.x)-(l3.z/l3.x)))-cam_1.z);
    }else{
      min_span = -w/2;
      max_span = w/2;
    }
    
    min = 256;
    
    int frx_ = 0, fry_ = 0;
    for(int i=0; i < 2*sample_pool; i++){
      
      r_x_ = 2*w;
      r_y_ = 2*h;
      
      while(r_x_ < -w/2 || r_x_ > w/2 || r_y_ > h/2 || r_y_ < -h/2){
        
        r_z_ = (int)random(min_span, max_span);
        
        //println(r_z_);
        
        frx_ = frx - (frx * r_z_ / focal_dist);
        fry_ = fry - (fry * r_z_ / focal_dist);
        //println("-> "+frx+","+fry);
        
        PVector line4 = new PVector(gen_cam.x, gen_cam.y, gen_cam.z);
  
        line4.sub(new PVector(frx_, fry_, r_z_));
       
        line4.z *= -1;
        line4.y *= -1;
        
        r_x_ = (int)(- gen_cam.x * (line4.z / line4.x));
        r_y_ = (int)(- gen_cam.x * (line4.y / line4.x));

      }
        
      gmc = getMeanColor((img_turn ? 1 : -1)*r_x_ + w/2, -r_y_ + h/2, !img_turn);
      if(gmc<min) {
        min = gmc;
        frz = r_z_;
      }
      
    }
    
    frx -= frx * frz / focal_dist;
    fry -= fry * frz / focal_dist;

    // finally add point to cloud
    if(img_turn){
      points[current_point++] = new PVector((float)frx, (float)fry, (float)frz);
    }else{
      points[current_point++] = new PVector((float)frz, (float)fry, -(float)frx);
    }
    
  }
  
  //to compute faster uncomment this (don't forget to uncomment the closing bracket):
  //if(frameCount % 50 == 0){
    background(255);
    drawSpheres();
    drawImages();
  //}
  
  rotate_camera();
  camera_check();

  // constantly alternate the image we are using as base
  img_turn = !img_turn;
}

void drawSpheres() {
  noStroke();
  fill(200, 100);
  lights();
  
  for(int i = 0; i < current_point; i++){ 
    translate((int)points[i].x, (int)points[i].y, (int)points[i].z);
    sphere(sphere_radius);
    translate(-(int)points[i].x, -(int)points[i].y, -(int)points[i].z);
  }
}

void drawImages(){
  if(show_img_1){image(g1, -w/2, -h/2);}
  if(show_img_2){
    translate(0, -h/2, w/2);
    rotateY(PI/2);
    image(g2, 0, 0);
  }
}

void rotate_camera(){
  // not the best approach but works...
  if(rotate_state != 0){
    if(rotate_state == 1){
      if(camera_angle + camera_rotate_inc > PI/2 && camera_angle < PI/2){
        camera_angle = PI/2;
        rotate_state =0;
      }else{
        camera_angle += camera_rotate_inc;
      }
    }else{
      if(camera_angle - camera_rotate_inc < 0){
        camera_angle = 0;
        rotate_state = 0;
      }else{
        camera_angle -= camera_rotate_inc;
      }
    }
  }
}

float getMeanColor(float a1, float a2, boolean img_turn) {
  float sum = 0;
  
  // this operation doesn't need so much detail
  // also not doing this makes the program run faster  
  /*
  int x,y;
  int nSteps = 8;

  for(int i=0; i < nSteps; i++) {
    x = (int)(a1 + sphere_radius*cos(i*2*PI/nSteps));
    y = (int)(a2 + sphere_radius*sin(i*2*PI/nSteps));
    if(img_turn){
      sum += g1.get((int)x, (int)y) >> 16 & 0xFF;
    }else{
      sum += g2.get((int)x, (int)y) >> 16 & 0xFF;
    }
  }
  return sum/(float)nSteps;
  */
  
  if(img_turn){
    sum = g1.get((int)a1, (int)a2) >> 16 & 0xFF;
  }else{
    sum = g2.get((int)a1, (int)a2) >> 16 & 0xFF;
  }
  return sum;
}

void keyPressed(){
  if(key == 'r' || key == 'R'){
    initialize();
  }
    
  if(key == '1'){
    show_img_1 = !show_img_1;
  }
  
  if(key == '2'){
    show_img_2 = !show_img_2;
  }
  
  if(key == 'n' || key == 'N'){
    //camera_angle = 0;
    rotate_state = -1;
  }
  
  if(key == 'm' || key == 'M'){
    //camera_angle = PI/2;
    rotate_state = 1;
  }
  
  if(key == ENTER){
    stop = !stop;
  }
}

void mousePressed(){
  if(mouseButton == LEFT){
    drag_mouse_x = mouseX;
    old_camera_angle = camera_angle;
  }
}

void mouseDragged(){
  if(mouseButton == LEFT){
     camera_angle = (old_camera_angle + map(drag_mouse_x - mouseX, 0, width, 0, 2*PI));
  }
}

void camera_check(){
  
   camera_angle = camera_angle % (2*PI);
   
  if(camera_angle < 0){
       camera_angle += 2*PI;
     }

}
