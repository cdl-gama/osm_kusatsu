/**
* Name: fixedpath2
* Author: mrks
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model fixedpath2

/* Insert your model definition here */




 
global {   
	file shape_file_roads  <- file("../includes/intersection/easy/simple_network.shp") ;
	file shape_file_nodes  <- file("../includes/intersection/easy/simple_nodes.shp");
	geometry shape <- envelope(shape_file_roads);
	int nb_people <-15;
	int nb_bus <- 0;
	int nb_route <- 3;
	int time_to_set_offset <- 1;
	int num; //交通量
	node_agt starting_point;
	graph road_network;
	graph road_network1; 
	graph kagayaki_network;
	graph pana_east_network;
	graph kasayama_network;
	map kagayaki_route;
	map kasayama_route;
	map pana_east_route;
	map general_speed_map;
	map general_cost_map;
	path kagayaki_path;
	path kasayama_path;
	path pana_east_path;
	node_agt t1;//スタート地点
	node_agt t2;//ゴール地点
	point t3;
	point t4;
	
	
	
	/*********************************************************************************************************************************/
	/* 
	*ここのソースをいじれば信号制御の際のパラメータの大切さを知ってもらえます。
	*信号制御の際の制御パラメータのうちの一つであるスプリットの値を保持する変数です 
	* スプリットは交差点内の信号の青の点灯時間と赤の点灯時間のバランスを取るための割合です。
	* 0.1 ~ 1.0 まで制御できるので以下の init のところを変えてみてください 
	* ex 100秒サイクルでスプリット0.3の場合　→　青30秒　赤70秒 
	* 0.1と0.9にすると結果がわかりやすいです。
	*
	/
	/**********************************************************************************************************************************/
	float sig_split parameter: "signal split" category: "signal sgent" min: 0.1 max: 1.0 init:0.5 step: 0.1;
	/*********************************************************************************************************************************/
	/****************************************** ****************************************************************************************/
	
	
	
	point save_route;
	file bus_shape_kagayaki  <- file('../icons/vehicles/bus_blue.png');
	file bus_shape_kasayama  <- file('../icons/vehicles/bus_green.png');
	file bus_shape_pana_east  <- file('../icons/vehicles/normal_yellow.png');
	file car_shape_empty  <- file('../icons/vehicles/normal_red.png');
	float current_hour update: (time / #sec);
	float update_hour <- 0.0;
	float time_to_thorw <- 1000.0;
	list<node_agt> start;
	list<node_agt> end;
	
	
	init {  
		
		create road from: shape_file_roads with:[id::int(read("id")),nblanes::int(read("lanes")),maxspeed::int(read("maxspeed")),highway::string(read("highway")),
			kasayama::int(read("kasayama")),kagayaki::int(read("kagayaki")),pana_east::int(read("pana-east"))] {
			
			
		    lanes <- 1;
		    maxspeed <- (lanes = 1 ? 30.0 : (lanes = 2 ? 50.0 : 70.0)) °km/°h;
		    geom_display <- shape+ (2.5 * lanes);
		    
		    if(kagayaki!=1){
		    	kagayaki <- 500;//重みを極端にする
		    }
		    if(kasayama!=1){
		    	kasayama <- 500;
		    }
		    if(pana_east!=1){
		    	pana_east <- 500;
		    }
		    switch oneway {
		    	match "no" {
		    		create road {
					  	lanes <- myself.lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						self.kagayaki <- myself.kagayaki;
						self.kasayama <- myself.kasayama;
						self.pana_east <- myself.pana_east;  
						myself.linked_road <- self;
						
						
						if(myself.kagayaki!=1){
					    	self.kagayaki <- 500;//重みを極端にする
					    }
					    if(myself.kasayama!=1){
					    	self.kasayama <- 500;
					    }
					    if(myself.pana_east!=1){
					    	self.pana_east <- 500;
					    }								
						
					  }
					  //lanes <- int(lanes /2.0 + 0.5);
				 }
		    	match "yes" {
		    		create road {
					  	lanes <- max([1, int (myself.lanes / 2.0)]);
						shape <- polyline(myself.shape.points);
						maxspeed <- myself.maxspeed;
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						geom_display <- shape+ (2.5 * lanes);
						myself.linked_road <- self;
						self.kagayaki <- myself.kagayaki;
						self.kasayama <- myself.kasayama;
						self.pana_east <- myself.pana_east; 
						
						if(myself.kagayaki!=1){
					    	self.kagayaki <- 500;//重みを極端にする
					    }
					    if(myself.kasayama!=1){
					    	self.kasayama <- 500;
					    }
					    if(myself.pana_east!=1){
					    	self.pana_east <- 500;
					    }
					  }
					  //lanes <- int(lanes /2.0 + 0.5);
				 }
				 match "-1" {
				 	lanes <- 1;
				 	self.linked_road <- self;
				 	shape <- polyline(reverse(shape.points));
				 	geom_display <- shape+ (2.5 * lanes);
				}
			}
			
		    maxspeed <- (lanes = 1 ? 30.0 : (lanes = 2 ? 50.0 : 70.0)) °km/°h;
		}
		
		create node_agt from: shape_file_nodes with:[is_traffic_signal::(string(read("type")) = "traffic_signals"),type::(string(read("type"))),highway::(string(read("highway")))]{
			split <- sig_split;
		}
		starting_point <- one_of(node_agt where each.is_traffic_signal);
		
		general_speed_map <- road as_map (each::(each.shape.perimeter / (each.maxspeed)));
		
		
		/*以下数行を書き換える */
		kagayaki_route <- road as_map(each::(each.kagayaki));//重みを
		kasayama_route <- road as_map(each::(each.kasayama));
		pana_east_route <- road as_map(each::(each.pana_east));
		road_network <-  (as_driving_graph(road, node_agt))with_weights general_speed_map;
		
		t1 <- (node_agt(5));
		t2 <- (node_agt(12));
		t3 <- (node_agt(8));
		t4 <- (node_agt(3));
		
		
		start <- node_agt where (each.highway = "start");
		end <- node_agt where (each.highway = "end");
		
				
	create people number: nb_people { 
			speed <- 50 #km /#h ;
			vehicle_length <- 10.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			security_distance_coeff <-0.0;  
			proba_respect_priorities <- 1.0;
			proba_respect_stops <- [1.0];
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
			d <- one_of(end); 
			target <- d;
			o <- one_of(start); 
//			location <- any_location_in(d);
//			current_path <- compute_path(graph: road_network, target: o);
//			mem_return_path <- current_path;
//			mem_return_current_road <- current_road;
//			mem_return_current_target <- current_target;
//			mem_return_targets <- targets ;
//			mem_return_final_target <- final_target;
			
			
		
		
//		if(length(road(current_road).all_agents )!= 0){
//		road(current_road).all_agents <- road(current_road).all_agents - self;
//		
////		if(road(current_road).agents_on = nil ){
////			road(current_road).agents_on <- road(current_road).agents_on + [[]];
////		}
//		}
		
					
			current_road <- nil;
			current_path <- nil;
			current_target <- nil;
			targets <- nil;
			final_target <- nil;
			
			
			
			location <- any_location_in(o);
			current_path <- compute_path(graph: road_network, target: target);
			mem_going_path <- current_path;
			mem_going_current_road <- current_road;
			mem_going_current_target <- current_target;
			mem_going_targets <- targets ;
			mem_going_final_target <- final_target;
		

		}
		
		
		create bus number: nb_bus { 
			speed <- 30 #km /#h ;
			vehicle_length <- 3.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			security_distance_coeff <- 4.0;//(1.5 - rnd(1000) / 1000);  
			proba_respect_priorities <- 1.0 - rnd(200/1000);
			proba_respect_stops <- [0.1];
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
		
			if(flip(0.5)){
				location <-  t1.location;//point("bus_terminal1");//スタート地点の指定に変更panaだけ別分ける可能性
				start <- t1;
				target <- t2;
				true_target <- t2;
				
			}else{
				location <-  t2.location;//point("bus_terminal1");//スタート地点の指定に変更panaだけ別分ける可能性
				start <- t2;
				target <- t1;
				true_target <- t1;
			}
		
		}	
		
		create dice;
			
	}
	
} 

species node_agt skills: [skill_road_node] {
	bool is_traffic_signal;
	string type;
	string highway;
	string end;
	int cycle <- 100; 
	int phase_time <- int(cycle*split) ;
	float split; 
	int counter;
	int offset <- 0;
	bool is_blue <- true;
	list<road> current_shows ; 
	list<node_agt> adjoin_node;
	string mode <- "independence";
	agent c1; 
	agent c2; 
	
	

//	//オフセット設定（広域信号制御の際に使用）
//	reflex set_offset when:time = time_to_set_offset and is_traffic_signal{
//		starting_point.mode <- "start";
//		loop i from: 0 to: length(starting_point.adjoin_node)-1 {
//			starting_point.adjoin_node[i].offset <- 0;
//		}	
//	}
//	
//	
//	//起点モード（広域信号制御の際に使用）
//	reflex set_adjoinnode when: time = 0{
//		
//		if(length(self.roads_out) >1){
//			loop i from: 0 to: length(self.roads_out) - 1 {
//				self.adjoin_node <- self.adjoin_node + [node_agt(road(roads_out[i]).target_node)] where each.is_traffic_signal;
//			}
//		}
//	}
//	

	reflex init_signals when: time = 0{
		

			if (length(roads_in) = 4) {
				if(is_blue){		
					current_shows <- [road(roads_in[0]),road(roads_in[2])];				
				}else{
					current_shows <- [road(roads_in[1]),road(roads_in[3])]; 
				}
			}
			
			if (length(roads_in) = 3) {		
				if(is_blue){
					current_shows <- [road(roads_in[0])];				
				}else{
					current_shows <- [road(roads_in[1]),road(roads_in[2])]; 
				}
			}
	
	}
	
	//chage timing
	reflex start when: counter >= phase_time and is_traffic_signal{
		
		
			counter <- 0;
			
	
		
			if(contains(bus,c1)){
				bus(c1).checked <- false;
			}
	
			if(contains(bus,c2)){
				bus(c2).checked <- false;
			}
		
			if(contains(people,c1)){
				people(c1).checked <- false;
			} 
			if(contains(people,c2)){
				people(c2).checked <- false;
			}	
			
			c1 <- nil;
			c2 <- nil;
			
			
			if (length(roads_in) = 4) {
				if(is_blue){		
					current_shows <- [road(roads_in[0]),road(roads_in[2])];
					phase_time <- int(cycle*split);		
				}else{
					current_shows <- [road(roads_in[1]),road(roads_in[3])]; 
					phase_time <- int(cycle*(1-split));	
				}
			}
			
			if (length(roads_in) = 3) {		
				if(is_blue){
					current_shows <- [road(roads_in[0])];	
					phase_time <- int(cycle*split);			
				}else{
					current_shows <- [road(roads_in[1]),road(roads_in[2])];
					phase_time <- int(cycle*(1-split));	 
				}
			}
			
			is_blue <- !is_blue;
			
			
			
	} 
	
	//4叉路用信号制御処理
	reflex stop4 when:is_traffic_signal and length(roads_in) = 4
	{
		
		counter <- counter + 1;
				
		if(length(current_shows) != 0){
			if(length(current_shows[0].all_agents) != 0 ){
				c1 <- current_shows[0].all_agents[0]; 
				
				if(contains(agents_at_distance(10.0),c1)){
					
					if(contains(bus,c1)){
						bus(c1).checked <- true;
					}
				
					if(contains(people,c1)){
						people(c1).checked <- true;
					}
				}
			}			
			
			if(length(current_shows[1].all_agents) != 0 ){
				c2 <- current_shows[1].all_agents[0];
				
				if(contains(agents_at_distance(10.0),c2)){
					if(contains(bus,c2)){
						bus(c2).checked <- true;
					}
				
					if(contains(people,c2)){
						people(c2).checked <- true;
					}
				}
			}
		}
	}
		
		
	//3叉路用信号制御処理		
	reflex stop3 when:is_traffic_signal and  length(roads_in) =  3{
		
		counter <- counter + 1;
			
		//現示の道路に車がいない時の処理
		if(length(current_shows) != 0){
			
			if(length(current_shows[0].all_agents) != 0 ){
				c1 <- current_shows[0].all_agents[0]; 
				
				if(contains(agents_at_distance(10.0),c1)){
					
					if(contains(bus,c1)){
						bus(c1).checked <- true;
					}
				
					if(contains(people,c1)){
						people(c1).checked <- true;
					}
				}
			}
			
			//現示の道路が二本以上の時
			if(length(current_shows) > 1){
				if(length(current_shows[1].all_agents) != 0 ){
					c2 <- current_shows[1].all_agents[0];
					
					if(contains(agents_at_distance(10.0),c2)){
						if(contains(bus,c2)){
							bus(c2).checked <- true;
						}
				
						if(contains(people,c2)){
							people(c2).checked <- true;
						}
					}
				}
			}
		}
	}
	
	aspect geom3D {
		if (is_traffic_signal) {	
			draw box(1,1,10) color:rgb("black");
			draw sphere(5) at: {location.x,location.y,12} color: is_blue ? #green : #red;
		}
	}
}





species road skills: [skill_road] { 
	string oneway;
	geometry geom_display;
	road riverse;
	int kasayama;
	int kagayaki;
	int pana_east;
	bool observation_mode <- true; //交通量観察モード　挙動が重いときはこれをfalseに
	int flow <- 1; //交通量
	float sum_traveltime <- 1.0;
	float number <- 1.0;
	float ave_traveltime<-0.0;
	list temp1 <- self.all_agents; // t = n -1 の交通量保持のためのリスト
	list test;
	int agents_on_cars;
	int car_num;
	point setnum <- {0.0,0.0};
	
	
	//交通量計測のためのメソッド	
	reflex when :observation_mode  {
		
		
				
		if(length(test) > 0){
			loop i from:0 to:length(test)-1{
				//road(people(test[i]).previous_road).sum_traveltime <- road(people(test[i]).previous_road).sum_traveltime + people(test[i]).travel_time;
			}
		}
			
		test <- all_agents - temp1;
		flow <- flow + length(test);
		temp1 <- self.all_agents;
		
	}
	

	
	
	reflex aaa when: time = 0{
		
	}
	
	
	
	aspect geom {    
		draw geom_display border:  #gray  color: #gray ;
	}  
}




	
	
species people skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	bool checked;
	node_agt target;
	node_agt source_node;
	node_agt true_target;
	node_agt o;
	node_agt d;
	float arrival_time <-1.0;
	float departure_time <-1.0;
	float travel_time <- 1.0;
	bool  route_changed <- false;
	agent temp <- current_road;
	agent previous_road  <- current_road;
	agent  mem_previous_road;
	point mem_going_final_target;
	path mem_going_path;
	point mem_going_current_target;
	agent mem_going_current_road;
	list<point> mem_going_targets;
	point mem_return_final_target;
	list<road> return_path_list;
	path mem_return_path;
	point mem_return_current_target;
	agent mem_return_current_road;
	list<point> mem_return_targets;
	bool f <- true;
	int dead_count;
	int waiting_time;
	point temp_location;

	
//	reflex set_arrivaltime when: current_road != temp {
//		travel_time <- time - departure_time;
//		departure_time <- time;
//		previous_road <- temp;
//		temp <- current_road;			
//	}
	
	
//	reflex aaa when: segment_index_on_road = -1{
//		
//		o <- one_of(node_agt where(each.highway = "start")); 
//		location <- any_location_in(o);
//		current_path <- compute_path(graph: road_network, target: target);
//	}
	



	

		
	reflex time_to_return when: self.location = any_location_in(d) and final_target = nil{
		
		
		
		road(current_road).all_agents <- road(current_road).all_agents - self;
//		road(current_road).agents_on[0][0] <- list(road(current_road).agents_on[0][0]) - self;
		remove self from: list(road(current_road).agents_on[0][0]);

		
		
		current_road <- nil;		
		current_path <- nil;
		current_target <- nil;
		targets <- nil;
		destination <- nil;
		distance_to_goal <- nil;
		location <- nil;
		dead_count <- 0;
		
		
		
		if(mem_return_current_road != nil){
		location <- any_location_in(d);
		current_index <- 0;
		current_road <- mem_return_current_road;
		road(current_road).all_agents <- road(current_road).all_agents + self;
		current_target <- mem_return_current_target;
		targets <- mem_return_targets ;
		f <- true;
		}else{
			current_path <- compute_path(graph: road_network, target: o);
			mem_return_path <- current_path;
			mem_return_current_road <- current_road;
			mem_return_current_target <- current_target;
			mem_return_targets <- targets ;
			mem_return_final_target <- final_target;
		}
		
//		road(current_road).all_agents <- road(current_road).all_agents + self;
//		if(road(current_road).agents_on[0] = []){
//		add [self] to: road(current_road).agents_on[0];
//		}
////		road(current_road).all_agents <- road(current_road).all_agents + self;
////		}
		
		
		
		
		final_target <- mem_return_final_target;
		current_path <- mem_return_path;
		
		
		
	}
	
	
	
	reflex time_to_go when: self.location = any_location_in(o) and final_target = nil {
		
		
		
		
		road(current_road).all_agents <- road(current_road).all_agents - self;
		remove self from: list(road(current_road).agents_on[0][0]);
		
		current_road <- nil;
		
		current_path <- nil;
		current_target <- nil;
	
		destination <- nil;
		location <- nil;
		distance_to_goal <- nil;
		dead_count <- 0;
		f <- true;
	
	
	
		
		current_road <- mem_going_current_road;
		location <- any_location_in(o);
		current_index <- 0;	
		current_target <- mem_going_current_target;
		targets <- mem_going_targets;
		final_target <- mem_going_final_target;	
		
		road(current_road).all_agents <- road(current_road).all_agents + self;


	
		current_path <- mem_going_path;
				
	}
	
	

	

//	
//	reflex time_to_force when:  (current_index = length(targets)-1) and f{	
//		
//		
//		add [self] to: road(current_road).agents_on[0];
//		f <- false;
//		
//	}
//	
	

	
	
	reflex dead_cnt when: real_speed = 0.0 and distance_to_goal = 0.0{
		dead_count <- dead_count + 1;
	}
	
	reflex init_dead_cnt when: real_speed > 3.0{
		dead_count <- 0;
	}
	
	

	
	
	
	
	reflex change_route when: self.location = any_location_in(o) and route_changed = true{
		
			road_network <- road_network with_weights general_cost_map;
			
			location <- any_location_in(d);
			current_path <- compute_path(graph: road_network, target: o);
			mem_return_path <- current_path;
			mem_return_current_road <- current_road;
			mem_return_current_target <- current_target;
			mem_return_targets <- targets + final_target;
			mem_return_final_target <- final_target;
			
			location <- any_location_in(o);
			current_path <- compute_path(graph: road_network, target: target);
			mem_going_path <- current_path;
			mem_going_current_road <- current_road;
			mem_going_current_target <- current_target;
			mem_going_targets <- targets;
			mem_going_final_target <- final_target;
			
		
	}
	
	reflex move when: current_path != nil and final_target != nil and checked = false{
		do drive;
	}
	
	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			draw box(vehicle_length+50, 150,150) at: loc rotate:  heading color: color;
			draw triangle(50) depth: 1 at: loc rotate:  heading + 90 color: #black;	
		}
	} 
	
	aspect icon {
		point loc <- calcul_loc();
			draw car_shape_empty size: vehicle_length   at: loc rotate: heading + 90 ;
	}
	
	point calcul_loc {
		float val <- (road(current_road).lanes - current_lane) + 0.5;
		val <- on_linked_road ? val * - 1 : val;
		if (val = 0) {
			return location; 
		} else {
			return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
		}
	}
} 




//路線バスの基本形エージェント
species bus skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	bool checked <-false;
	bool reverse <- true;
	node_agt target ;
	node_agt true_target ;
	node_agt start ;
	node_agt bus_start;
	int n <-1;
	int m <- 0;//rnd(n);//乱数でバスのルートを決定

	
	reflex change when :current_path = nil{	
		final_target <- nil;
	}
	
	
	
	//信号に引っかかった後の処理
	reflex time_to_go when: final_target = nil and checked = true {
		
		
		if(true_target != nil){
			target <- true_target;
			true_target <- nil;
		}
		
		
		if(m=0){
			road_network <- road_network with_weights kagayaki_route;//重みを地図に適応		
			current_path <- compute_path(graph: road_network,target: target);
		}
		
		if(m=1){
			road_network <- road_network with_weights kasayama_route;//重みを地図に適応
			current_path <- compute_path(graph: road_network,target: target);
		}
	}	
	


	//目的地（終着バスターミナル）についた時の処理
	 reflex time_to_restart when: final_target = nil and checked = false{		

		
		
		if(self.location = any_location_in(true_target)){
			self.location <- any_location_in(start);	
		}
		
		
		
		if(m=0){
			road_network <- road_network with_weights kagayaki_route;//重みを地図に適応		
			current_path <- compute_path(graph: road_network,target: target);
}
		
		if(m=1){
			road_network <- road_network with_weights kasayama_route;//重みを地図に適応
			current_path <- compute_path(graph: road_network,target: target);
		}
		
		if(m=2){
			location <- t4;
			road_network <- road_network with_weights pana_east_route;//重みを地図に適応
			current_path <- compute_path(graph: road_network,target: target);
			
			//write current_path;
		}
	} 
	
	reflex move when: current_path != nil and final_target != nil{//道が決まり、目的地が決まれば動く
		do drive;
		write current_road;
	}
	
	
	

	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			draw box(vehicle_length, 1,1) at: loc rotate:  heading color: color;
			draw triangle(0.5) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
		}
	}
	
	 
	
	aspect icon {
		point loc <- calcul_loc();
			if(m =0){
			draw bus_shape_kagayaki size: vehicle_length   at: loc rotate: heading + 90 ;
			}
			if(m = 1)
				{
			draw bus_shape_kasayama size: vehicle_length   at: loc rotate: heading + 90 ;	
					}
		}
	
	point calcul_loc {
		float val <- (road(current_road).lanes - current_lane) + 0.5;
		val <- on_linked_road ? val * - 1 : val;
		if (val = 0) {
			return location; 
		} else {
			return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
		}
	}

}


species dice {
	
	int agent_num;
	int loop_count <-0;
	bool mem <- true;
	
	reflex throw_the_dice when: current_hour = time_to_thorw+1{
		
//		if(loop_count < nb_people*0.1){
		loop i from: 0 to: nb_people*0.1-1{ 
			agent_num <- rnd(nb_people-1);
		ask people[agent_num]{
				self.route_changed <- true;
			}	
		}
		loop_count <- loop_count + 1;
//		}


		loop i from: 0 to: length(road)-1{ 
			road[i].ave_traveltime <- road[i].sum_traveltime / road[i].flow;
			road[i].setnum <- {time,road[i].flow};
			road[i].sum_traveltime <- 1.0;
			road[i].flow <- 1;
		}
		general_cost_map <- road as_map (each::(each.ave_traveltime));	

		
		time_to_thorw <- time_to_thorw + 1000;	
	}
	
	
}




experiment traffic_simulation type: gui {
	
	
	
	
	
	output {
		display city_display type: opengl{
			species road aspect: geom refresh: false;
			species node_agt aspect: geom3D;
			species people aspect: icon;
			species bus aspect: icon;
		}
		
		
//		display ChartScatterHistory{
//		chart "Number-Time" type:scatter
//			{
//				//datalist ["road0","road1","road2","road3","road4","road5","road6","road7"] value: [road[0].setnum,road[1].setnum,road[2].setnum,road[3].setnum,road[4].setnum,road[5].setnum,road[6].setnum,road[7].setnum] color:[°red,°blue,°black,°green,°pink,°yellow,°purple,°gold] line_visible:false;				
//				datalist["road1","road5","road7"] value:[road[1].setnum,road[5].setnum,road[7].setnum] color:[°blue,°pink,°purple] line_visible:false;
//			}
//	}
	}
}