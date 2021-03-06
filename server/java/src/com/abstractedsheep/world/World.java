/*
 * Copyright 2011
 *
 *   This file is part of Mobile Shuttle Tracker.
 *
 *   Mobile Shuttle Tracker is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   Mobile Shuttle Tracker is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with Mobile Shuttle Tracker.  If not, see <http://www.gnu.org/licenses/>.
 */

package com.abstractedsheep.world;

import com.abstractedsheep.extractor.DynamicJSONExtractor;
import com.abstractedsheep.extractor.Netlink.RouteJson;
import com.abstractedsheep.extractor.Netlink.RouteJson.RouteCoordinateJson;
import com.abstractedsheep.extractor.Netlink.StopJson;
import com.abstractedsheep.extractor.Netlink.StopJson.StopRouteJson;
import com.abstractedsheep.extractor.StaticJSONExtractor;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;

/**
 * This class houses all of the dynamic (Shuttle) and static (Route and Stop) data.
 * Virtually data modification and manipulation occurs within this class, excluding ETA
 * calculations. The dynamic and static data is stored in final HashMaps and only have
 * read-only access.
 *
 * @author saiumesh
 */
public class World {
    //this value is in milliseconds
    private static final int SHUTTLE_LIFE_SPAN = (1000 * 45);

    //XXX These collections should ONLY be maintained and ONLY modified by this class
    private HashMap<Integer, Route> routeList;
    private HashMap<Integer, Shuttle> shuttleList;
    private HashMap<String, Stop> stopList;
    private final StaticJSONExtractor staticExtractor;
    private final DynamicJSONExtractor dynamicExtractor;


    public World(StaticJSONExtractor staticData, DynamicJSONExtractor dynamicData) {
        this.routeList = new HashMap<Integer, Route>();
        this.shuttleList = new HashMap<Integer, Shuttle>();
        this.stopList = new HashMap<String, Stop>();
        this.staticExtractor = staticData;
        this.dynamicExtractor = dynamicData;
    }

    //TODO staticExtractor does not need to be global
    public void generateWorld() {
        staticExtractor.readDataFromURL();

        for (RouteJson r : staticExtractor.getRouteList()) {
            this.addRoute(r);
        }

        for (StopJson stop : staticExtractor.getStopList()) {
            this.addStop(stop);
        }
    }

    private void addStop(StopJson stop) {
        List<Integer> routes = new ArrayList<Integer>();
        for (StopRouteJson sj : stop.getRoutes()) {
            routes.add(sj.getId());
        }

        Stop s = new Stop(new Coordinate(stop.getLatitude(), stop.getLongitude()), stop.getShort_name(), stop.getName());
        HashMap<Integer, Route> tempRouteList = this.routeList;
        for (Integer i : routes) {
            Route r = tempRouteList.get(i);
            s.addRoute(r);
            r.addStop(s);
            s.snapToRoute(r);
            routeList.put(i, r);
        }
        stopList.put(s.getShortName(), s);
    }

    private void addRoute(RouteJson r) {
        List<Coordinate> coords = new ArrayList<Coordinate>();
        for (RouteCoordinateJson rc : r.getCoords()) {
            coords.add(new Coordinate(rc.getLatitude(), rc.getLongitude()));
        }

        Route route = new Route(r.getId(), r.getName(), (ArrayList<Coordinate>) coords);
        routeList.put(route.getIdNum(), route);
    }

    public void updateWorld() {
        dynamicExtractor.readDataFromURL();
        HashMap<Integer, Shuttle> updatedShuttleList = dynamicExtractor.getDynamicData();

        //update current shuttle list
        for (Integer shuttleId : updatedShuttleList.keySet()) {
            if (this.shuttleList.containsKey(shuttleId)) {
                Shuttle temp = shuttleList.get(shuttleId);
                temp.updateShuttle(updatedShuttleList.get(shuttleId));
                this.shuttleList.put(shuttleId, temp);
            } else {
                this.shuttleList.put(shuttleId, updatedShuttleList.get(shuttleId));
            }
        }

        //remove all shuttles that have not been update for a while.
        HashMap<Integer, Shuttle> tempList = shuttleList;
        for (Integer shuttleId : tempList.keySet()) {
            long age = tempList.get(shuttleId).getAge();

            if (age >= SHUTTLE_LIFE_SPAN) {
                shuttleList.remove(shuttleId);
            }
        }
    }

    /**
     * @return a read-only version of the routeList
     */
    public HashMap<Integer, Route> getRouteList() {
        return (HashMap<Integer, Route>) Collections.unmodifiableMap(routeList);
    }

    /**
     * @return a read-only version of the shuttleList
     */
    public HashMap<Integer, Shuttle> getShuttleList() {
        return (HashMap<Integer, Shuttle>) Collections.unmodifiableMap(shuttleList);
    }

    /**
     * @return a read-only version of the stopList
     */
    public HashMap<String, Stop> getStopList() {
        return (HashMap<String, Stop>) Collections.unmodifiableMap(stopList);
    }

}