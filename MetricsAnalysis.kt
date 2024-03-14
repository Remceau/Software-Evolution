import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.nio.file.Paths
import kotlin.io.path.readText
import kotlin.math.roundToInt

/*
    This is a script written in Kotlin for analysing the results of Radon, a code analysis
    tool written in Python. It reads out the output provided by Radon and determines averages
    per module and finds outliers.

    The following Radon commands should be run as inputs:
    - radon cc openlibrary -s -j -O openlibrary-cc.json
    - radon mi openlibrary -s -j -O openlibrary-mi.json
    - radon raw openlibrary -j -O openlibrary-raw.json
    - radon hal openlibrary -j -O openlibrary-hal.json

    This script relies on the following dependencies:
    Kotlin 1.8.20
    com.google.code.gson:gson:2.10.1
 */

/** Extracts the module from [path]. */
fun extractModule(path: String): String = path.substringBeforeLast("\\").substringAfter("openlibrary\\")

/** Stores all info on one file. */
data class Info(
    val raw: String,
    val mi: Double,
    val mirank: String,
    val loc: Int,
    val lloc: Int,
    val sloc: Int,
    val comments: Int,
    val multi: Int,
    val blank: Int,
    val singleComments: Int,
    val halstead: HalsteadInfo,
    val halsteadPerFunction: Map<String, HalsteadInfo>,
    val mccabePerFunction: Map<String, McCabeInfo>,
    val path: List<String> = raw.split("\\").toList(),
    var module: String = extractModule(raw),
    val isTest: Boolean = "scripts" in path || "test" in path || "tests" in path,
    val isPlugin: Boolean = "vendor" in path,
)

data class McCabeInfo(
    val type: String,
    val rank: String,
    val offset: Int,
    val name: String,
    val endline: Int,
    val complexity: Int,
    val lineno: Int,
    val closures: JsonArray,
) {

    constructor(obj: JsonObject) : this(
        obj.get("type").asString,
        obj.get("rank").asString,
        obj.get("col_offset").asInt,
        obj.get("name").asString,
        obj.get("endline").asInt,
        obj.get("complexity").asInt,
        obj.get("lineno").asInt,
        obj.get("closures")?.asJsonArray ?: JsonArray(),
    )
}

data class HalsteadInfo(
    val h1: Int,
    val h2: Int,
    val N1: Int,
    val N2: Int,
    val vocab: Int,
    val length: Int,
    val calculatedLength: Double,
    val volume: Double,
    val difficulty: Double,
    val effort: Double,
    val time: Double,
    val bugs: Double,
) {

    constructor(obj: JsonObject) : this(
        obj.get("h1").asInt,
        obj.get("h2").asInt,
        obj.get("N1").asInt,
        obj.get("N2").asInt,
        obj.get("vocabulary").asInt,
        obj.get("length").asInt,
        obj.get("calculated_length").asDouble,
        obj.get("volume").asDouble,
        obj.get("difficulty").asDouble,
        obj.get("effort").asDouble,
        obj.get("time").asDouble,
        obj.get("bugs").asDouble,
    )
}

data class Averages(
    val files: Int,
    val loc: Double,
    val lloc: Double,
    val sloc: Double,
    val comments: Double,
    val multi: Double,
    val blank: Double,
    val singleComments: Double,
    val complexity: Double,
    val h1: Double,
    val h2: Double,
    val N1: Double,
    val N2: Double,
    val vocab: Double,
    val length: Double,
    val calculatedLength: Double,
    val volume: Double,
    val difficulty: Double,
    val effort: Double,
    val time: Double,
    val bugs: Double,
)

val files = mutableSetOf<Info>()

fun printModules() {
    val allModules = files.filter { !it.isTest && !it.isPlugin }.map { it.module }.distinct()
    println("${allModules.size} modules:")
    println(allModules.joinToString("\n"))
}

fun determineBadMI() {
    val sorted = files.sortedByDescending { it.sloc }
    val badMi = files.filter { it.mirank != "A" }.sortedBy { it.mi }.map { sorted.indexOf(it) }
    println(badMi)
}

fun main() {
    // Load in all data
    val gson = JsonParser()
    val cc = gson.parse(Paths.get("openlibrary-cc.json").readText()).asJsonObject
    val hal = gson.parse(Paths.get("openlibrary-hal.json").readText()).asJsonObject
    val mi = gson.parse(Paths.get("openlibrary-mi.json").readText()).asJsonObject
    val raw = gson.parse(Paths.get("openlibrary-raw.json").readText()).asJsonObject

    val allKeys = cc.keySet() + hal.keySet() + mi.keySet() + raw.keySet()
    for (key in allKeys) {
        val cck = cc.get(key)?.asJsonArray
        val halk = hal.get(key).asJsonObject
        val mik = mi.get(key).asJsonObject
        val rawk = raw.get(key).asJsonObject
        files += Info(
            key,
            mik.get("mi").asDouble,
            mik.get("rank").asString,
            rawk.get("loc").asInt,
            rawk.get("lloc").asInt,
            rawk.get("sloc").asInt,
            rawk.get("comments").asInt,
            rawk.get("multi").asInt,
            rawk.get("blank").asInt,
            rawk.get("single_comments").asInt,
            HalsteadInfo(halk.getAsJsonObject("total")),
            halk.getAsJsonObject("functions").asMap().mapValues { HalsteadInfo(it.value.asJsonObject) },
            cck?.asJsonArray?.asList()?.map { McCabeInfo(it.asJsonObject) }?.associateBy { it.name } ?: emptyMap<String, McCabeInfo>().also {
                // Init.py files have no complexity data!
                if (key.endsWith("__init__.py")) return@also
                println("Could not find complexity data for $key")
            },
        )
    }

    // Merge modules with one file!
    while (true) {
        var didSomething = false
        files.groupBy { it.module }.values.onEach { list ->
            if (list.size != 1) return@onEach
            if (list.all { "\\" !in it.module }) return@onEach
            list.onEach { it.module = it.module.substringBeforeLast("\\") }
            didSomething = true
        }
        if (!didSomething) break
    }

    // Determine averages by module
    val averages = files
        .groupBy { it.module }
        .filter { it.value.size > 1 }
        .filter { it.value.all { !it.isTest } }
        .mapValues { (_, inlist) ->
            val hals = inlist.map { it.halstead }
            Averages(
                inlist.size,
                inlist.map { it.loc }.average(),
                inlist.map { it.lloc }.average(),
                inlist.map { it.sloc }.average(),
                inlist.map { it.comments }.average(),
                inlist.map { it.multi }.average(),
                inlist.map { it.blank }.average(),
                inlist.map { it.singleComments }.average(),
                inlist.flatMap { it.mccabePerFunction.values }.sumOf { it.complexity }.toDouble() / inlist.count { it.mccabePerFunction.isNotEmpty() },
                hals.map { it.h1 }.average(),
                hals.map { it.h2 }.average(),
                hals.map { it.N1 }.average(),
                hals.map { it.N2 }.average(),
                hals.map { it.vocab }.average(),
                hals.map { it.length }.average(),
                hals.map { it.calculatedLength }.average(),
                hals.map { it.volume }.average(),
                hals.map { it.difficulty }.average(),
                hals.map { it.effort }.average(),
                hals.map { it.time }.average(),
                hals.map { it.bugs }.average(),
            )
        }
        .toSortedMap(Comparator.comparing { it })

    for ((module, data) in averages) {
        println("${module.replace("\\", "/").replace("_", "\\_").substringAfter("openlibrary/").substringAfter("vendor/infogami/")} & ${data.files} & ${data.sloc.roundToInt()} & ${if (data.complexity.isNaN()) "NaN" else data.complexity.roundToInt()} & ${data.volume.roundToInt()} \\\\")
    }
    println("Finished! (${averages.keys.count { !it.startsWith("vendor") }})")
}

