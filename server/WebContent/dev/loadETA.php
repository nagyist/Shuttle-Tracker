<?php
include_once("application.php");

include_once("apps/data_service.php");  
include_once("apps/routecoorddistances.php");
echo DataService::displayETAs();
DataServiceData::recordStats("Get Next ETA"); 
?>
