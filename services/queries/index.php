<?php

define('SAMPLES_QUERIES_DIR', 'samples/queries/');
define('SAMPLES_DATA_DIR', 'samples/data/');
define('SAMPLE_EXT', '.js');
define('LOCAL', in_array($_SERVER['SERVER_NAME'], array('localhost', 'reportgrid.local')) || intval($_SERVER['SERVER_NAME']) > 0);

$categories = array(
	'QU' => array("name" => 'Query', "sequence" => 0),
	'VZ' => array("name" => 'Visualization', "sequence" => 0),
	'TR' => array("name" => 'Track', "sequence" => 50)
);

if(LOCAL)
{
	define('REPORTGRID_QUERY_API', '/rg/queries/js/reportgrid-query.js');
	define('REPORTGRID_CHARTS_API', '/rg/charts/js/reportgrid-charts.js');
	define('REPORTGRID_CSS_API', '/rg/charts/css/rg-charts.css');
	$categories['XX'] = array('name' => 'Test', 'sequence' => 1000);
} else {
	define('REPORTGRID_QUERY_API', 'http://api.reportgrid.com/js/reportgrid-queries.js');
	define('REPORTGRID_CHARTS_API', 'http://api.reportgrid.com/js/reportgrid-charts.js');
	define('REPORTGRID_CSS_API', 'http://api.reportgrid.com/css/rg-charts.css');
}

function categories()
{
	global $categories;
	$result = array();
	foreach($categories as $key => $value)
	{
		$result[] = array('category' => $value['name'], 'code' => $key);
	}
	return $result;
}

function categoryOptions($cat)
{
	$d = dir(SAMPLES_QUERIES_DIR);
	$results = array();
	while(false !== ($entry = $d->read())) {
		if($cat != ($p = substr($entry, 0, 2)))
			continue;
		$results[] = array('sample' => $entry, 'title' => extractTitle($entry));
	}
	usort($results, 'optionComparison');
	return $results;
}

function extractTitle($sample)
{
	return array_pop(explode('-', basename($sample, SAMPLE_EXT), 2));
}

function compareCategory($v)
{
	global $categories;
	$c = @$categories[substr($v, 0, 2)]['sequence'];
	if($c === null)
		return 1000;
	else
		return $c;
}

function sampleComparison($a, $b)
{
	$v = compareCategory($a['sample']) - compareCategory($b['sample']);
	if($v !== 0)
		return $v;
	else
		return $a['sample']>$b['sample'];
}

function optionComparison($a, $b)
{
	return substr($a['sample'], 2) > substr($b['sample'], 2);
}

function listSamples($filtered = true)
{
	$d = dir(SAMPLES_QUERIES_DIR);
	$results = array();
	while(false !== ($entry = $d->read())) {
		if(('.' == ($c = substr($entry, 0, 1))) || ($filtered && ($c == '_' || $c == '-')))
			continue;
		$results[] = array('sample' => $entry, 'title' => extractTitle($entry));
	}
	usort($results, 'sampleComparison');
	return $results;
}

function infoSample($sample)
{
	$result = parseContent(file_get_contents(SAMPLES_QUERIES_DIR.basename($sample)));
	$result['title']  = extractTitle($sample);
	$result['sample'] = $sample;
	return $result;
}

function parseContent($content)
{
	$info = array();
	$parts = explode('//**', $content);
	foreach($parts as $part)
	{
		$pair = explode("\n", $part, 2);
		// first line is the section
		$key = trim(strtolower($pair[0]));
		if(!$key) continue;
		// the rest is the content
		$value = trim($pair[1]);
		if($key == 'load')
		{
			$info['data'] = "function data() {\n\t return ".file_get_contents(SAMPLES_DATA_DIR.$value.'.json').";\n}";
		} else {
			$info[$key] = $value;
		}
	}

	return $info;
}

function infoSamples()
{
	$list = listSamples(true);
	$result = array();
	foreach($list as $item)
	{
		if(substr($item['sample'], 0, 2) == "XX")
			continue;
		$result[] = infoSample($item['sample']);
	}
	return $result;
}

function display($sample)
{
	$info = infoSample($sample);
	$QUERY_API = REPORTGRID_QUERY_API;
	$VIZ_API = REPORTGRID_CHARTS_API;
	$CSS_API = REPORTGRID_CSS_API;
	require('template.php');
	exit;
}

function json($v)
{
	$json = json_encode($v);
	if(@$_GET['callback'])
	{
		echo $_GET['callback']."($json);";
	} else {
		echo $json;
	}
	exit;
}

if(!isset($_GET['action']))
{
	echo "<ul>\n";
	foreach(listSamples() as $item)
		echo "\t<li>{$item['title']}</li>\n";
	echo "</ul>";
	exit;
}

switch($_GET['action'])
{
	case 'list':
		json(listSamples());
		break;
	case 'categories':
		json(categories());
		break;
	case 'options':
		json(categoryOptions($_GET['category']));
		break;
	case 'info':
		json(infoSample($_GET['sample']));
		break;
	case 'display':
		display($_GET['sample']);
		break;
	default:
		echo "INVALID ACTION";
}