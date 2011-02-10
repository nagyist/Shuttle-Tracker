/*
 * This class is currently set up for demonstration.
 * It is heavily commented for educational purposes.
 */

package com.abstractedsheep.extractor;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Set;

import com.abstractedsheep.extractor.Shuttle.Point;

public class Shuttle {
	private int shuttleId;
	private HashMap<String, Stop> stops;
	private HashMap<String, Integer> stopETA;
	private String cardinalPoint;
	private String shuttleName;
	private int speed;
	private static Point currentLocation;
	private boolean isWestShuttle;
	private RouteFinder finder;
	private static int routeID;
	
	// Jackson requires a constructor with no parameters to be available
	// Also notice 'this.' preceding the variables, this makes it clear that the variable
	// is a global variable and although it is not necessary to use 'this.' if you do not
	// have a local variable by the same name, it is still a good idea to include it
	public Shuttle(ArrayList<Route> rt) {
		this.shuttleId = -1;
		this.stops = new HashMap<String, Stop>();
		this.stopETA = new HashMap<String, Integer>();
		this.shuttleName = "Bus 42";
		this.cardinalPoint = "North";
		this.speed = 0;
		this.currentLocation = new Point();
		this.isWestShuttle = true;
		finder = new RouteFinder(rt);
		routeID = rt.get(0).getIdNum();
	}
	
	// This constructor is not required by Jackson, but it makes manually creating a new point a
	// one line operation.
	public Shuttle(int shuttleId, int routeId, ArrayList<Route> rt) {
		// Here, 'this.' is necessary because we have a local variable named the same as the global
		this.shuttleId = shuttleId;
		this.stops = new HashMap<String, Stop>();
		this.stopETA = new HashMap<String, Integer>();
		this.shuttleName = "Bus 42";
		this.cardinalPoint = "North";
		this.speed = 0;
		this.currentLocation = new Point();
		this.isWestShuttle = true;
		finder = new RouteFinder(rt);
		routeID = rt.get(0).getIdNum();
	}
	
	
	// Jackson will not work unless all of the variables have accessors and mutators
	// Since these usually only have one line of code in them, put the entire method
	// on a single line to increase readability
	public int getShuttleId() { return this.shuttleId; }
	public void setShuttleId(int shuttleId) { this.shuttleId = shuttleId; }
	
	public int getRouteId() { return routeID; }
	
	public HashMap<String, Stop> getStops() { return stops; }
	public void setStops(HashMap<String, Stop> stops) { this.stops = stops; }
	
	public int getSpeed() { return speed; }
	public void setSpeed(int newSpd) { this.speed = (speed > 0) ? newSpd : 25; }
	
	public static Point getCurrentLocation() { return currentLocation; }
	public void setCurrentLocation(Point newLocation) { 
		this.currentLocation = newLocation;
		finder.changeCurrentLocation(currentLocation);
	}
	
	
	public String getCardinalPoint() { return cardinalPoint; }
	public void setCardinalPoint(String cardinalPoint) { this.cardinalPoint = cardinalPoint; }
	
	public String getName() { return shuttleName; }
	public void setName(String newName) { this.shuttleName = newName; }

	public HashMap<String, Integer> getStopETA() { return stopETA; }
	
	public String getRouteName() { return (routeID == 1) ? "East Campus" : "West Route"; }
	public void setRoute(String routename) {
		isWestShuttle = (routename.equals("West Route")) ? true : false;
		}

	// These next two methods are not required by Jackson
	// They are here to add data to stops
	public void addStop(String stopName, Stop p) { 
		if(p.getRouteMap().containsKey(routeID))
			stops.put(stopName, p);
	}
	
	/**
	 * Method determines ETA to the given stop based on the current speed and the
	 * distance to the stop based on the given route information.
	 * @param stopName - desired stop name
	 * @param routeList - contains a list of coordinates for the route
	 * @return time to reach destination or -1 if the stop does not exist on the shuttle's route
	 */
	public int getETAToStop(String stopName, ArrayList<Route> routeList) {		
		//If only to get the ETA to a particular stop, return the time, but for all general intentions
		//it might be better to save the times in a HashMap as it may make writing to a file easier.
		Point p = null;;
		try{
			p = stops.get(stopName).getLocation();
		} catch(NullPointerException ex) {
			//if the stop does not exist in the map, then the above line will throw a NPE
			//since you cannot get data from a null object.
			return -1;
		}
		
		double distance = (calculateDistance(p));
		int time = (int) ((distance / this.speed) * 60);
		this.stopETA.put(stopName, time);
		return time;
	}
	
	/**calculates the straight line distance between the given stop location and the shuttle's location
	 * The formula used to calculate this distance is the haversine formula
	 * {@link http://www.movable-type.co.uk/scripts/latlong.html}
	 * @param p - stop's location
	 * @return distance to stop
	 */
	private static double calculateDistance(Point p) {
		double earthRadius = 3961.3; //radius in miles
		Point curr = getCurrentLocation();
		double changeInLat = curr.lat - p.lat;
		double changeInLong = curr.lon - p.lon;
		double a = (Math.sin(changeInLat / 2) * Math.sin(changeInLat / 2)) +
					(Math.cos(p.lon) * Math.cos(curr.lon) * (Math.sin(changeInLong / 2) * Math.sin(changeInLong / 2)));
		double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1- a));
		
		return (earthRadius * c);
	}
	
	@Override
	public boolean equals(Object obj) {
		Shuttle s = (Shuttle) obj;
		return this.shuttleId == s.getShuttleId();
		
	}

	// If you create a class within a class, make sure it is static
	// This class follows the same rules as above
	public static class Point {
		private double lat;
		private double lon;
			
		public Point() {
			lat = 0;
			lon = 0;
		}
				
		public Point(double lat, double lon) {
			this.lat = lat;
			this.lon = lon;
		}	
				
		public double getLat() { return lat; }	
		public void setLat(double lat) { this.lat = lat; }
		
		public double getLon() { return lon; }
		public void setLon(double lon) { this.lon = lon; }
		
		public String toString() { return "(" + this.lat + ", " + this.lon + ")"; }
	}
	
	/**
	 * The purpose of this inner class is to calculate the distance and time for the shuttle to
	 * get to the desired stop.
	 * @author jonnau
	 *
	 */
	@SuppressWarnings("unused")
	private static class RouteFinder {
		ArrayList<Route> routeList;
		ArrayList<Point> locList;
		//this value is allowable error in degrees (~5-10 feet)
		private double tolerance = (5.0 * Math.pow(10, -4));
		private boolean foundRoute;
		
		/**
		 * 
		 * @param r - shuttle's route
		 * @param loc - current location of shuttle
		 */
		public RouteFinder(Route r, Point loc) {
			this.routeList = new ArrayList<Route>();
			this.routeList.add(r);
			this.locList = new ArrayList<Point>();
			locList.add(loc);
			foundRoute = false;
		}
		
		public RouteFinder(ArrayList<Route> rt) {
			routeList = rt;
			this.locList = new ArrayList<Point>();
			foundRoute = false;
		}

		public void changeCurrentLocation(Point pt) {
			if(locList.size() > 10)
				locList.remove(0);
			locList.add(pt);
			determineRouteOfShuttle();
		}
		
		private void determineRouteOfShuttle() {
			//using the given routes, determine which route the
			//shuttle is following
			ArrayList<Shuttle.Point> list = null;
			Point p1 = null, p2 = null;
			double[] distanceArray = { 999, 999 };
			int index = 0;
			double distance = 0.0;
			
			for(Route route : routeList) {
				list = route.getCoordinateList();
				for(int i = 0; i < list.size(); i++) {
					p1 = list.get(i);
					distance = calculateDistance(p1);
					
					if(distanceArray[index] >= distance)
						distanceArray[index] = distance;
				}
				index++;
			}
			
			if(distanceArray[0] != distanceArray[1]) {
				foundRoute = true;
				routeID  = (distanceArray[0] < distanceArray[1]) ?
						routeList.get(0).getIdNum() : routeList.get(1).getIdNum();
			}
		}

		/**
		 * calculates distance from stop
		 * @param stop - desired stop
		 * @return distance to stop.
		 */
		public double getDistanceToStop(Stop stop) {
			return 0.0;
		}
		
		/**
		 * calculates arrival time to stop
		 * @param stop - desired stop
		 * @return time to stop.
		 */
		public int getTimeToStop(Stop stop) {
			return 0;
		}
	}
}