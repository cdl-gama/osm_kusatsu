/**
* Name: kusatsucity4
* Author: mrks
* Description: 
* Tags: Tag1, Tag2, TagN
*/



model kusatsucity3

/* Insert your model definition here */
/**
* Name: kusatsucity2
* Author: mrks
* Description: 
* Tags: Tag1, Tag2, TagN
*/


/*
 * kusatsu tarffic simulation
 * 
 */


global {
	file shape_file_roads  <-file("../includes/kusatsu_city_mapdata/ver2/kusatsu_city_roads.shp");
	file shape_file_nodes  <-file("../includes/kusatsu_city_mapdata/ver2/kusatsu_city_nodes.shp");
	file shape_file_buildings <-file("../includes/kusatsu_city_mapdata/ver2/kusatsu_city_buildings.shp");
	file shape_file_bounds <- file("../includes/kusatsu_city_mapdata/ver2/kusatsu_city_roads.shp");
	
	geometry shape <- envelope(shape_file_roads);

	int nb_people <- 1500;
	int nb_bus <- 30;
	int time_to_set_offset <- 1;
	
	node_agt starting_point;
	
	graph road_network;
	graph kagayaki_network;
	graph kasayama_network;
	graph pana_east_network;
	graph pana_west_network;
	graph kasayamaJK_network;
	
	map general_speed_map;
	map general_cost_map;
	map kagayaki_route;
	map kasayama_route;
	map pana_east_route;
	map pana_west_route;
	map kasayamaJK_route;
	
	path kagayaki_path;
	path kasayama_path;
	path pana_east_path;
	path pana_west_path;
	path kasayamaJK_path;
	
	node_agt bus_stop1;
	node_agt bus_stop2;
	node_agt bus_stop3;
	node_agt bus_stop4;
	node_agt bus_stop5;
	node_agt bus_stop6;
	node_agt bus_stop7;
	node_agt bus_stop8;
	
	float current_hour update: (time / #sec);
	float update_hour <- 0.0;
	float time_to_thorw <- 3600.0;
	float sig_split ;
	
	
	
	file bus_shape_kagayaki  <- file('../icons/vehicles/bus_blue.png');
	file bus_shape_kasayama  <- file('../icons/vehicles/bus_green.png');
	file bus_shape_pana_east  <- file('../icons/vehicles/bus_green.png');
	file bus_shape_pana_west  <- file('../icons/vehicles/bus_green.png');
	file bus_shape_kasayamaJK  <- file('../icons/vehicles/bus_blue.png');
	file car_shape_empty  <- file('../icons/vehicles/normal_red.png');
	
	
	init{
		create road from: shape_file_roads with:[id::int(read("id")),nblanes::int(read("lanes")),maxspeed::int(read("maxspeed")),highway::string(read("highway")),
			kasayama::int(read("kasayama")),kagayaki::int(read("kagayaki")),pana_east::int(read("pana-east")),pana_west::int(read("pana-west"))]{

		    lanes <- 1;
		    maxspeed <- (lanes = 1 ? 30.0 : (lanes = 2 ? 50.0 : 60.0)) °km/°h;
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
		    if(pana_west!=1){
		    	pana_west <- 500;
		    }
		    
		    switch oneway {
		    	match "no" {
		    		create road{
		    			lanes <- max([1, int (myself.lanes / 2.0)]);
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						
						self.kagayaki <- myself.kagayaki; 
						self.kasayama <- myself.kasayama;
						self.pana_east <- myself.pana_east;
						self.pana_west <- myself.pana_west;   
						
						myself.linked_road <- self;
						
						if(myself.kagayaki!=1){
					    	self.kagayaki <- 500;
					    }
					    if(myself.kasayama!=1){
					    	self.kasayama <- 500;
					    }
					    if(myself.pana_east!=1){
					    	self.pana_east <- 500;
					    }
					    if(myself.pana_west!=1){
					    	self.pana_west <- 500;
					    }						
					}
				}
		    	match "yes" {
		    		create road {
					  	lanes <- max([1, int (myself.lanes / 2.0)]);
						shape <- polyline(myself.shape.points);
						maxspeed <- myself.maxspeed;
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						
						self.kagayaki <- myself.kagayaki;
						self.kasayama <- myself.kasayama;
						self.pana_east <- myself.pana_east;
						self.pana_west <- myself.pana_west;  
						
						myself.linked_road <- self;
						
						if(myself.kagayaki!=1){
					    	self.kagayaki <- 500;
					    }
					    if(myself.kasayama!=1){
					    	self.kasayama <- 500;
					    }
					    if(myself.pana_east!=1){
					    	self.pana_east <- 500;
					    }
					    if(myself.pana_west!=1){
					    	self.pana_west <- 500;
					    }
					}
				}
				match "-1" {
					lanes <- 1;
				 	self.linked_road <- self;
					shape <- polyline(reverse(shape.points));
				}
			}
			
		    maxspeed <- (lanes = 1 ? 30.0 : (lanes = 2 ? 50.0 : 70.0)) °km/°h;
		}
		
		create node_agt from: shape_file_nodes with:[is_traffic_signal::(string(read("highway")) = "traffic_signals"),highway::(string(read("highway"))),end::(string(read("end")))]{
		
		}
		starting_point <- one_of(node_agt where each.is_traffic_signal);
		
		general_speed_map <- road as_map (each::(each.shape.perimeter / (each.maxspeed)));
		
		kagayaki_route  <- road as_map(each::(each.kagayaki));
		kasayama_route  <- road as_map(each::(each.kasayama));
		pana_east_route <- road as_map(each::(each.pana_east));
		pana_west_route <- road as_map(each::(each.pana_west));
			
		road_network <-  as_driving_graph(road, node_agt)with_weights general_speed_map;
				
		bus_stop1 <- one_of(node_agt where (each.highway = "bus_terminal1"));//立命館大学1
		bus_stop2 <- one_of(node_agt where (each.highway = "bus_terminal2"));//立命館大学2
		bus_stop3 <- one_of(node_agt where (each.highway = "bus_terminal3"));//立命館大学3
		bus_stop4 <- one_of(node_agt where (each.highway = "bus_terminal4"));//南草津駅乗り場1
		bus_stop5 <- one_of(node_agt where (each.highway = "bus_terminal5"));//南草津駅乗り場2
		bus_stop6 <- one_of(node_agt where (each.highway = "bus_terminal6"));//南草津駅乗り場3
		bus_stop7 <- one_of(node_agt where (each.highway = "bus_terminal7"));//南草津駅乗り場4
		bus_stop8 <- one_of(node_agt where (each.highway = "bus_terminal8"));//南草津駅降り場
		
		create building from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}		
				
		create car number: nb_people { 
			speed <- 50 #km /#h ;
			vehicle_length <- 10.0 #m;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5+ (rnd(500) / 500);
			security_distance_coeff <-(1.5 - rnd(1000) / 1000);  
			proba_respect_priorities <- 0.1;
			proba_respect_stops <- [0.0];
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 0.5 + rnd(500) / 1000;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
			d <- one_of(node_agt); 
			target <- d;
			o <- one_of(node_agt); 
			location <- any_location_in(d);
			home <- one_of(building);
			current_path <- compute_path(graph: road_network, target: o);
			mem_return_path <- current_path;
			mem_return_current_road <- current_road;
			mem_return_current_target <- current_target;
			mem_return_targets <- targets ;
			mem_return_final_target <- final_target;
			
			if(current_road != nil){
			road(current_road).all_agents <- road(current_road).all_agents - self;
			remove self from: list(road(current_road).agents_on[0][0]);
			}
			
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
			vehicle_length <- 6.0 #m;
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
				location <-  bus_stop1.location;
				start <- bus_stop1;
				target <- bus_stop8;			
				
			}else{
				location <-  bus_stop8.location;
				start <- bus_stop8;
				target <- bus_stop1;
			}
			
			 m <- rnd(2);
			
			if(m=0){
				road_network <- road_network with_weights kagayaki_route;
			}
		
			if(m=1){
				road_network <- road_network with_weights kasayama_route;
			}
			if(m=2){
				road_network <- road_network with_weights pana_east_route;
			}	
			current_path <- compute_path(graph: road_network,target: target);
			mem_path <- current_path;
			mem_current_road <- current_road;
			mem_current_target <- current_target;
			mem_targets <- targets;
			mem_final_target <- final_target;
			
		}
		
		//create dice;
		
    }		
}

species building {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}


species node_agt skills: [skill_road_node] {
	bool is_traffic_signal;
	string type;
	string highway;
	string end;
	int cycle <- 100; 
	float split <- rnd(1.0,0.1); 
	int counter;
	int offset <- 0;
	bool is_blue <- true;
	list<road> current_shows ; 
	list<node_agt> adjoin_node;
	string mode <- "independence";
	int phase_time <- int(cycle*split);
	agent c1; 
	agent c2; 
	
	

	//オフセット設定（広域信号制御の際に使用）
//	reflex set_offset when:time = time_to_set_offset and is_traffic_signal{
//		starting_point.mode <- "start";
//		loop i from: 0 to: length(starting_point.adjoin_node)-1 {
//			starting_point.adjoin_node[i].offset <- 0;
//		}	
//	}
	
	
//	//起点モード（広域信号制御の際に使用）
//	reflex set_adjoinnode when: time = 0{
//		
//		if(length(self.roads_out) >1){
//			loop i from: 0 to: length(self.roads_out) - 1 {
//				self.adjoin_node <- self.adjoin_node + [node_agt(road(roads_out[i]).target_node)] where each.is_traffic_signal;
//			}
//		}
//	}
	

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
	
	//cahge timing
	reflex start when: counter >= cycle*split+offset and is_traffic_signal{
		
		
			counter <- 0; 
			
		
			if(contains(bus,c1)){
				bus(c1).checked <- false;
			}
	
			if(contains(bus,c2)){
				bus(c2).checked <- false;
			}
		
			if(contains(car,c1)){
				car(c1).checked <- false;
			} 
			if(contains(car,c2)){
				car(c2).checked <- false;
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
				 	phase_time <- int(cycle*split) ;			
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
				
					if(contains(car,c1)){
						car(c1).checked <- true;
					}
				}
			}			
			
			if(length(current_shows[1].all_agents) != 0 ){
				c2 <- current_shows[1].all_agents[0];
				
				if(contains(agents_at_distance(10.0),c2)){
					if(contains(bus,c2)){
						bus(c2).checked <- true;
					}
				
					if(contains(car,c2)){
						car(c2).checked <- true;
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
				
					if(contains(car,c1)){
						car(c1).checked <- true;
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
				
						if(contains(car,c2)){
							car(c2).checked <- true;
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
	string highway;
	geometry geom_display;
	road riverse;
	int kasayama;
	int kagayaki;
	int pana_east;
	int pana_west;
	list test;
	bool observation_mode <- true; 
	int flow <- 0; 
	list temp1 <- self.all_agents; 
	float sum_traveltime <- 1.0;
	float number <- 1.0;
	float ave_traveltime<-0.0;
	point setnum <- {0.0,0.0};
	
	
	reflex when :observation_mode  {
		
				
		if(length(test) > 0){
			loop i from:0 to:length(test)-1{
				if(contains(car,test[i])){
					//road(car(test[i]).previous_road).sum_traveltime <- road(car(test[i]).previous_road).sum_traveltime + car(test[i]).travel_time;
				}
			}
		}
			
		test <- all_agents - temp1;
		flow <- flow + length(test);
		temp1 <- self.all_agents;
	}
	
	aspect geom {    
		draw geom_display border:  #gray  color: #gray ;
	}  
}
	
species car skills: [advanced_driving] { 
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
	building home;
	point mem_return_final_target;
	list<road> return_path_list;
	path mem_return_path;
	point mem_return_current_target;
	agent mem_return_current_road;
	list<point> mem_return_targets;
	
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
	


	reflex time_to_home when:self.location = final_target{
		temp_location <- self.location;
		self.location <- any_location_in(home);
	}
	

		
	reflex time_to_return when: self.location = any_location_in(d) and final_target = nil{
		
		
		
		if(current_road != nil){
			road(current_road).all_agents <- road(current_road).all_agents - self;
			remove self from: list(road(current_road).agents_on[0][0]);
		}
		
		current_road <- nil;
		current_road <- mem_return_current_road;
		
		
		
		current_path <- nil;
		current_target <- nil;
		targets <- nil;
		final_target <- nil;
		destination <- nil;
		distance_to_goal <- nil;
		location <- nil;
		dead_count <- 0;
		
		
		current_index <- 0;
		current_road <- mem_return_current_road;
		
		if(current_road != nil){
		road(current_road).all_agents <- road(current_road).all_agents + self;
		}
		
		
		current_target <- mem_return_current_target;
		targets <- mem_return_targets ;
		target <- o;
		self.location <- any_location_in(d);
		final_target <- mem_return_final_target;
		current_path <- mem_return_path;
		
		
		
	}
	
	
	
	reflex time_to_go when: self.location = any_location_in(o) and final_target = nil {
		
		
		if(current_road != nil){
			road(current_road).all_agents <- road(current_road).all_agents - self;
			remove self from: list(road(current_road).agents_on[0][0]);
		}
	
		current_road <- nil;
		current_road <- mem_going_current_road;
		
		current_path <- nil;
		current_target <- nil;
		targets <- nil;
		final_target <- nil;
		destination <- nil;
		location <- nil;
		distance_to_goal <- nil;
		dead_count <- 0;
	
	
		
		current_road <- mem_going_current_road;
		if(current_road != nil){
		road(current_road).all_agents <- road(current_road).all_agents + self;
		}
		current_index <- 0;	
		current_target <- mem_going_current_target;
		targets <- mem_going_targets;
		final_target <- mem_going_final_target;	
		target <- d;
		self.location <- any_location_in(o);
		current_path <- mem_going_path;
		
				
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
			draw box(vehicle_length, 1,1) at: loc rotate:  heading color: color;
			draw triangle(0.5) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
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


species bus skills: [advanced_driving] { 
	rgb color <- rnd_color(255);
	bool checked <-false;
	node_agt target ;
	node_agt bus_start;
	node_agt start;
	float travel_time;
	int m ;
	path mem_path;
	point mem_current_target;
	point mem_final_target;
	agent mem_current_road;
	list<point> mem_targets;
	
	reflex change when :current_path = nil{	
		final_target <- nil;
	}
	
	 reflex time_to_restart when: self.location = any_location_in(target){
	
		if(current_road != nil){
			road(current_road).all_agents <- road(current_road).all_agents - self;
			remove self from: list(road(current_road).agents_on[0][0]);
		}
		
		
		self.location <- any_location_in(start);		
		current_index <- 0;	
		current_road <- nil;
		current_path <- nil;
		current_target <- nil;
		targets <- nil;
		final_target <- nil;
		
		current_road <- mem_current_road;
		current_path <- mem_path;
		current_target <- mem_current_target;
		targets <- mem_targets;
		final_target <- any_location_in(target);
	} 
	
	reflex time_to_force when: current_index = length(targets)-1 and real_speed < 1{
		self.location <- any_location_in(target);	
	}
	
	reflex move when: current_path != nil and final_target != nil {//道が決まり、目的地が決まれば動く
		do drive;
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
			if(m = 1){
				draw bus_shape_kasayama size: vehicle_length   at: loc rotate: heading + 90 ;	
			}
			if(m = 2){
				draw bus_shape_pana_east size: vehicle_length   at: loc rotate: heading + 90 ;	
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
	point setnum <- {0.0,0.0};
	float ave_ave_traveltime; 
	float count <- 0.0;
	
	reflex throw_the_dice when: current_hour = time_to_thorw+1{
		
		
	
		
		loop i from: 0 to: nb_people*0.1-1{ 
			agent_num <- rnd(nb_people-1);
		ask car[agent_num]{
				self.route_changed <- true;
				write(self);
			}	
		}
		

		loop i from: 0 to: length(road)-1{ 
			if(road[i].flow != 0){
			road[i].ave_traveltime <- road[i].sum_traveltime / road[i].flow;
			}
			if(road[i].highway = "trunk" or road[i].highway = "primary"){
			ave_ave_traveltime <- ave_ave_traveltime + road[i].ave_traveltime;
			count <- count + 1.0;
			}
			road[i].sum_traveltime <- 1.0;
			road[i].flow <- 1;
		}
		
		ave_ave_traveltime <- ave_ave_traveltime / count;
		setnum <- {length(car),ave_ave_traveltime};
		
		general_cost_map <- road as_map (each::(each.ave_traveltime));	
		
		time_to_thorw <- time_to_thorw + 3600;	
	}
	
	
}


experiment traffic_simulation type: gui {
	
	parameter "nb_cars: " var: nb_people  min: 0 max: 1000 category: "car" ;
	parameter "nb_buses: " var: nb_bus category: "bus" ;
	
	output {
		display city_display type: opengl{
			species road aspect: geom refresh: false;
			species node_agt aspect: geom3D;
			species building aspect: base ;
			species car aspect: icon;
			species bus aspect: icon;
		}
		
		
//		display ChartScatterHistory{
//		chart "Ave_traveltime-Number" type:scatter
//			{
//				//datalist ["road0","road1","road2","road3","road4","road5","road6","road7"] value: [road[0].setnum,road[1].setnum,road[2].setnum,road[3].setnum,road[4].setnum,road[5].setnum,road[6].setnum,road[7].setnum] color:[°red,°blue,°black,°green,°pink,°yellow,°purple,°gold] line_visible:false;				
//				//datalist["ave_traveltime"] value:[dice[0].setnum] color:[°blue] line_visible:true;
//			}
//	}
	}
}
