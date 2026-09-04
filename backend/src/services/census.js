import { config, TTL } from "../config.js";
import { remember } from "../cache.js";
import { fetchJSON, fetchJSONSoft } from "../http.js";
import { STATE_BY_FIPS } from "../data/states.js";

const BASE = "https://api.census.gov/data";

/**
 * ACS 5-year detailed tables we read. Every metric below is derived only from
 * these raw variables — nothing is estimated, interpolated, or invented.
 */
const VARIABLES = [
  "B01003_001E", // total population
  "B19013_001E", // median household income
  "B17001_001E", "B17001_002E", // poverty universe / below poverty
  "B25077_001E", // median home value
  "B25064_001E", // median gross rent
  "B25001_001E", // housing units
  "B25003_001E", "B25003_002E", // occupied units / owner occupied
  "B14001_001E", "B14001_008E", // school enrollment universe / enrolled undergrad
  "B15003_001E", // educational attainment universe (25+)
  "B15003_017E", "B15003_018E", "B15003_019E", "B15003_020E",
  "B15003_021E", "B15003_022E", "B15003_023E", "B15003_024E", "B15003_025E",
];

const num = (v) => {
  const n = Number(v);
  // Census uses large negative sentinels (-666666666 etc.) for suppressed values.
  return Number.isFinite(n) && n > -1e9 ? n : null;
};

const ratio = (a, b) => (a === null || b === null || b === 0 ? null : (a / b) * 100);

/** metric id -> derivation from one year of raw variables */
export const CENSUS_METRICS = {
  population: {
    name: "Total Population",
    category: "Population",
    unit: "people",
    format: "integer",
    betterWhen: "neutral",
    definition:
      "The total number of people living in the county, estimated by the American Community Survey 5-year averages.",
    table: "B01003",
    derive: (r) => num(r.B01003_001E),
  },
  median_income: {
    name: "Median Household Income",
    category: "Economy",
    unit: "USD",
    format: "currency",
    betterWhen: "up",
    definition:
      "The income of the middle household in the county — half of households earn more, half earn less. Reported in the dollars of each survey year, so it is not adjusted for inflation across years.",
    table: "B19013",
    derive: (r) => num(r.B19013_001E),
  },
  poverty_rate: {
    name: "Poverty Rate",
    category: "Economy",
    unit: "%",
    format: "percent",
    betterWhen: "down",
    definition:
      "The share of people whose household income falls below the federal poverty threshold for their household size.",
    table: "B17001",
    derive: (r) => ratio(num(r.B17001_002E), num(r.B17001_001E)),
  },
  median_home_value: {
    name: "Median Home Value",
    category: "Housing",
    unit: "USD",
    format: "currency",
    betterWhen: "neutral",
    definition:
      "The middle value of owner-occupied homes, as estimated by the owners themselves in the American Community Survey.",
    table: "B25077",
    derive: (r) => num(r.B25077_001E),
  },
  median_rent: {
    name: "Median Gross Rent",
    category: "Housing",
    unit: "USD/month",
    format: "currency",
    betterWhen: "neutral",
    definition:
      "The middle monthly rent paid by renters, including any utilities the renter pays separately.",
    table: "B25064",
    derive: (r) => num(r.B25064_001E),
  },
  housing_units: {
    name: "Housing Units",
    category: "Housing",
    unit: "units",
    format: "integer",
    betterWhen: "neutral",
    definition:
      "The total count of houses, apartments, and other places built to be lived in — occupied or vacant.",
    table: "B25001",
    derive: (r) => num(r.B25001_001E),
  },
  homeownership_rate: {
    name: "Homeownership Rate",
    category: "Housing",
    unit: "%",
    format: "percent",
    betterWhen: "neutral",
    definition:
      "The share of occupied homes that are lived in by their owner rather than rented.",
    table: "B25003",
    derive: (r) => ratio(num(r.B25003_002E), num(r.B25003_001E)),
  },
  hs_attainment_rate: {
    name: "High School Attainment",
    category: "Education",
    unit: "%",
    format: "percent",
    betterWhen: "up",
    definition:
      "The share of adults aged 25 and older who finished high school or went further. This measures attainment across all adults, not the graduation rate of a single class.",
    table: "B15003",
    derive: (r) => {
      const parts = [17, 18, 19, 20, 21, 22, 23, 24, 25].map((i) =>
        num(r[`B15003_0${i}E`])
      );
      if (parts.some((p) => p === null)) return null;
      return ratio(
        parts.reduce((a, b) => a + b, 0),
        num(r.B15003_001E)
      );
    },
  },
  college_enrollment_rate: {
    name: "College Enrollment Share",
    category: "Education",
    unit: "%",
    format: "percent",
    betterWhen: "up",
    definition:
      "Of everyone aged 3 and older who is enrolled in school, the share enrolled in undergraduate college.",
    table: "B14001",
    derive: (r) => ratio(num(r.B14001_008E), num(r.B14001_001E)),
  },
  school_enrollment: {
    name: "School Enrollment",
    category: "Education",
    unit: "students",
    format: "integer",
    betterWhen: "neutral",
    definition:
      "The total number of people aged 3 and older enrolled in school, from nursery school through graduate school.",
    table: "B14001",
    derive: (r) => num(r.B14001_001E),
  },
};

function sourceFor(metricId, year) {
  const m = CENSUS_METRICS[metricId];
  return {
    name: `American Community Survey 5-Year Estimates, table ${m.table}`,
    organization: "U.S. Census Bureau",
    url: `https://data.census.gov/table/ACSDT5Y${year}.${m.table}`,
    lastUpdated: `${year}-12-01`,
    methodology:
      "Rolling 5-year average of continuous household survey responses. Every value is an estimate with a margin of error; smaller counties have wider error bands.",
  };
}

const round = (value, format) =>
  format === "percent" ? Math.round(value * 10) / 10 : Math.round(value);

/** Raw variable row for one county and one ACS vintage, or null if unpublished. */
async function fetchYear(stateFips, countyFips, year) {
  return remember(`census:${stateFips}:${countyFips}:${year}`, TTL.metrics, async () => {
    const url =
      `${BASE}/${year}/acs/acs5?get=NAME,${VARIABLES.join(",")}` +
      `&for=county:${countyFips}&in=state:${stateFips}` +
      (config.censusKey ? `&key=${config.censusKey}` : "");
    const json = await fetchJSONSoft(url, { label: `census ${year}` });
    if (!Array.isArray(json) || json.length < 2) return null;
    const [header, row] = json;
    const out = {};
    header.forEach((h, i) => (out[h] = row[i]));
    return out;
  });
}

/**
 * Returns { name, metrics: { id: { history: [{year, value}], source, ...meta } } }.
 * History omits years the Census did not publish — gaps are never filled in.
 */
export async function fetchCensusMetrics(stateFips, countyFips) {
  return remember(`census-metrics:${stateFips}:${countyFips}`, TTL.metrics, async () => {
    const years = [...config.acsYears].sort((a, b) => a - b);
    const rows = await Promise.all(years.map((y) => fetchYear(stateFips, countyFips, y)));

    let name = null;
    const metrics = {};
    for (const [id, def] of Object.entries(CENSUS_METRICS)) {
      const history = [];
      rows.forEach((row, i) => {
        if (!row) return;
        if (!name && row.NAME) name = row.NAME;
        const value = def.derive(row);
        if (value !== null) history.push({ year: years[i], value: round(value, def.format) });
      });
      if (history.length === 0) continue;
      metrics[id] = {
        id,
        name: def.name,
        category: def.category,
        unit: def.unit,
        format: def.format,
        betterWhen: def.betterWhen,
        definition: def.definition,
        history,
        source: sourceFor(id, history[history.length - 1].year),
      };
    }
    return { name, metrics };
  });
}

/** All counties in a state, from the newest ACS vintage. */
export async function fetchCounties(stateFips) {
  if (!config.censusKey) {
    const err = new Error("CENSUS_API_KEY is not set - the Census API requires a key.");
    err.code = "UPSTREAM";
    throw err;
  }
  return remember(`counties:${stateFips}`, TTL.locations, async () => {
    const url =
      `${BASE}/${config.latestAcsYear}/acs/acs5?get=NAME&for=county:*&in=state:${stateFips}` +
      (config.censusKey ? `&key=${config.censusKey}` : "");
    const json = await fetchJSON(url, { label: "census counties" });
    const state = STATE_BY_FIPS.get(stateFips);
    return json
      .slice(1)
      .map(([fullName, sFips, cFips]) => ({
        id: `${sFips}${cFips}`,
        stateFips: sFips,
        countyFips: cFips,
        stateAbbr: state?.abbr ?? "",
        stateName: state?.name ?? "",
        // "York County, South Carolina" -> "York County"
        county: String(fullName).split(",")[0].trim(),
        displayName: String(fullName),
      }))
      .sort((a, b) => a.county.localeCompare(b.county));
  });
}
