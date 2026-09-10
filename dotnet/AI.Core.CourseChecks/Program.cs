using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.CourseChecks;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

var engine = new SichuanFanProjectionEngine();
var concealedPair = SichuanTileCodec.BuildCount18(new[] { 8, 8 });
var melds = new[]
{
    new SichuanMeldView(SichuanMeldType.Peng, 0, 1, 1),
    new SichuanMeldView(SichuanMeldType.Peng, 2, 1, 2),
    new SichuanMeldView(SichuanMeldType.MeldedGang, 13, 1, 3),
    new SichuanMeldView(SichuanMeldType.Peng, 15, 1, 4),
};
var projected = engine.Project(concealedPair, melds, SichuanWinType.SelfDraw);
Require(projected.HandType == "jin_gou_diao", $"expected jin_gou_diao, got {projected.HandType}");
Require(projected.GenCount == 1, $"exposed gang must count as one root, got {projected.GenCount}");
Require(projected.UncappedFan == 3, $"jin-gou-diao plus root must be 3 fan, got {projected.UncappedFan}");
Require(projected.CappedFan == 3 && projected.PerPayerScore == 9,
    $"self draw must charge each payer 2^3+1=9, got fan={projected.CappedFan} score={projected.PerPayerScore}");

var neutralHand = SichuanTileCodec.BuildCount18(new[] { 0, 0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 18, 19, 22 });
var neutralState = SichuanStateCodec.FromRaw(
    seatIndex: 0,
    dealerSeat: 0,
    currentSeat: 0,
    wallCount: 40,
    hand18: neutralHand,
    visible18: new int[27],
    roundIndex: 1,
    handCounts: new[] { 14, 13, 13, 13 });
var decision = new SichuanAiFacade().DecideDiscard(neutralState);
var minimumShanten = decision.Candidates.Min(candidate => candidate.Shanten);
var maximumLiveAtMinimum = decision.Candidates
    .Where(candidate => candidate.Shanten == minimumShanten)
    .Max(candidate => candidate.LiveUkeire);
var chosen = decision.Candidates.Single(candidate => candidate.TileType == decision.Action.TileType);
Require(decision.ClassicPattern is not null && decision.ClassicPattern.Type is >= 1 and <= 4,
    "discard result must expose the mutually-exclusive classic-pattern classification");
Require(chosen.Shanten == minimumShanten,
    $"ordinary-play discard must minimize shanten first, chose {chosen.Shanten} while best is {minimumShanten}");
Require(chosen.LiveUkeire == maximumLiveAtMinimum,
    $"equal-shanten discard must maximize strict live ukeire, chose {chosen.LiveUkeire} while best is {maximumLiveAtMinimum}");
Console.WriteLine($"SICHUAN_COURSE_TEMPO_PASS tile={chosen.TileType} shanten={chosen.Shanten} live={chosen.LiveUkeire}");

var classic = new SichuanClassicPatternEngine();
var classicFixtures = new[]
{
    (Expected: 1, Tiles: new[] { 0,1,2,3,4,5,6,7,8,9,10,12,13,17 }),
    (Expected: 2, Tiles: new[] { 0,1,2,3,4,5,6,7,8,9,9,12,15,17 }),
    (Expected: 3, Tiles: new[] { 0,1,2,3,4,5,9,9,13,13,14,18,22,26 }),
    (Expected: 4, Tiles: new[] { 0,1,2,3,4,5,9,9,13,13,14,17,17,26 }),
};
foreach (var fixture in classicFixtures)
{
    var analysis = classic.Analyze(SichuanTileCodec.BuildCount18(fixture.Tiles));
    Require(analysis.Type == fixture.Expected,
        $"classic pattern expected type {fixture.Expected}, got {analysis.Type}: {analysis}");
    Console.WriteLine($"SICHUAN_CLASSIC_PATTERN_PASS type={analysis.Type} pairs={analysis.EffectivePairCount} raw={analysis.RawPairCount}");
}

var apparentPairFixture = new[] { 4, 7, 9, 12, 13, 15, 15, 16, 16, 17, 18, 21, 22, 25 };
var apparentAnalysis = classic.Analyze(SichuanTileCodec.BuildCount18(apparentPairFixture));
Require(apparentAnalysis.RawPairCount == 2 && apparentAnalysis.EffectivePairCount == 0
    && apparentAnalysis.HasApparentPairOnly,
    $"raw pairs consumed by the best mutually-exclusive decomposition must be marked apparent-only: {apparentAnalysis}");
Console.WriteLine($"SICHUAN_CLASSIC_APPARENT_PAIR_PASS tiles={string.Join(',', apparentPairFixture)} raw={apparentAnalysis.RawPairCount} effective={apparentAnalysis.EffectivePairCount}");

foreach (var source in classicFixtures.Where(item => item.Expected is 3 or 4))
{
    var hand = SichuanTileCodec.BuildCount18(source.Tiles);
    var before = classic.Analyze(hand);
    var scored = source.Tiles.Distinct().Select(tile =>
    {
        var after = (int[])hand.Clone();
        after[tile]--;
        var analysis = classic.Analyze(after);
        return (tile, score: classic.EvaluateDiscard(before, after), analysis);
    }).OrderByDescending(item => item.score).ThenBy(item => item.tile).ToArray();
    var bestScore = scored.Max(item => item.score);
    var best = scored.Where(item => Math.Abs(item.score - bestScore) <= 0.000001).ToArray();
    Require(best.All(item => item.analysis.EffectivePairCount == 2 && item.analysis.HasTwoPairsAndHalf),
        $"type {source.Expected} best classic target must preserve two effective pairs plus the half-pair structure");
    Console.WriteLine($"SICHUAN_CLASSIC_TWO_PAIR_TARGET type={source.Expected} top={string.Join(';', scored.Take(5).Select(item => $"{item.tile}:{item.score:F2}/p{item.analysis.EffectivePairCount}/half{item.analysis.HasTwoPairsAndHalf}"))}");
}

var sortMethod = typeof(SichuanDecisionEngine).GetMethod(
    "SortDiscardCandidates",
    System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
Require(sortMethod is not null, "ordinary discard ordering contract must remain available");
var orderingFixture = new List<SichuanCandidateDetail>
{
    new() { TileType = 0, Shanten = 1, LiveUkeire = 99, ClassicPatternScore = 99, SetPreservationScore = 99, WaitShapeScore = 99, Score = 9999 },
    new() { TileType = 1, Shanten = 0, LiveUkeire = 8, ClassicPatternScore = 0, SetPreservationScore = 0, WaitShapeScore = 0, Score = 0 },
    new() { TileType = 2, Shanten = 0, LiveUkeire = 7, ClassicPatternScore = 99, SetPreservationScore = 99, WaitShapeScore = 99, Score = 9999 },
    new() { TileType = 3, Shanten = 0, LiveUkeire = 8, ClassicPatternScore = 2, SetPreservationScore = 0, WaitShapeScore = 0, Score = 0 },
    new() { TileType = 4, Shanten = 0, LiveUkeire = 8, ClassicPatternScore = 2, SetPreservationScore = 1, WaitShapeScore = 0, Score = 0 },
    new() { TileType = 5, Shanten = 0, LiveUkeire = 8, ClassicPatternScore = 2, SetPreservationScore = 1, WaitShapeScore = 1, Score = -9999 },
};
var ordered = (List<SichuanCandidateDetail>)sortMethod!.Invoke(null, new object?[] { orderingFixture, 1, null })!;
Require(ordered.Select(item => item.TileType).Take(6).SequenceEqual(new[] { 5, 4, 3, 1, 2, 0 }),
    $"course ordering must be shanten/live/classic/set/wait before blended score, got {string.Join(',', ordered.Select(item => item.TileType))}");
Console.WriteLine("SICHUAN_COURSE_ORDERING_PASS order=shanten>live>classic>set>wait>score");

// Blind phase: produce every answer from question inputs before opening the
// separately declared answer key. No teacher answer enters state or features.
var blindPredictions = new Dictionary<string, int>();
var exerciseDetails = new Dictionary<string, SichuanDecisionResult>();
foreach (var question in CourseExerciseFixtures.Questions)
{
    Require(question.Tiles.Length == 14, $"{question.Id} must contain exactly 14 tiles");
    Require(question.Tiles.GroupBy(tile => tile).All(group => group.Count() <= 4),
        $"{question.Id} cannot contain more than four copies of a tile");
    var hand = SichuanTileCodec.BuildCount18(question.Tiles);
    var state = SichuanStateCodec.FromRaw(0, 0, 0, 40, hand, new int[27],
        roundIndex: 1, handCounts: new[] { 14, 13, 13, 13 });
    var result = new SichuanAiFacade().DecideDiscard(state);
    blindPredictions[question.Id] = result.Action.TileType;
    exerciseDetails[question.Id] = result;
}

var correct = 0;
var errorClasses = new Dictionary<string, int>(StringComparer.Ordinal);
foreach (var question in CourseExerciseFixtures.Questions)
{
    var predicted = blindPredictions[question.Id];
    var accepted = CourseExerciseFixtures.AnswerKey[question.Id];
    var matches = accepted.Contains(predicted);
    if (matches) correct++;
    var detail = exerciseDetails[question.Id].Candidates.Single(item => item.TileType == predicted);
    Console.WriteLine($"SICHUAN_COURSE_EXERCISE id={question.Id} expectedType={question.ClassicType} actualType={exerciseDetails[question.Id].ClassicPattern?.Type} predicted={predicted} accepted={string.Join('|', accepted)} match={matches} shanten={detail.Shanten} live={detail.LiveUkeire}");
    if (!matches)
    {
        var acceptedDetails = exerciseDetails[question.Id].Candidates
            .Where(item => accepted.Contains(item.TileType)).ToArray();
        var bestAcceptedShanten = acceptedDetails.Min(item => item.Shanten);
        var bestAcceptedLive = acceptedDetails.Where(item => item.Shanten == bestAcceptedShanten)
            .Max(item => item.LiveUkeire);
        var errorClass = bestAcceptedShanten > detail.Shanten
            ? "COURSE_VS_EXACT_SHANTEN"
            : bestAcceptedLive < detail.LiveUkeire
                ? "UKEIRE_DEFINITION_OR_INPUT"
                : "STRUCTURE_TIE_BREAK";
        errorClasses[errorClass] = errorClasses.GetValueOrDefault(errorClass) + 1;
        var candidateAudit = exerciseDetails[question.Id].Candidates
            .OrderBy(item => item.Shanten)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenByDescending(item => item.ClassicPatternScore)
            .Select(item => $"{item.TileType}:s{item.Shanten}/l{item.LiveUkeire}[{string.Join(',', item.ImprovingTiles)}]/c{item.ClassicPatternScore:F2}/p{item.SetPreservationScore:F2}/w{item.WaitShapeScore:F2}");
        Console.WriteLine($"SICHUAN_COURSE_EXERCISE_AUDIT id={question.Id} class={errorClass} candidates={string.Join(';', candidateAudit)}");
    }
}
Console.WriteLine($"SICHUAN_COURSE_EXERCISE_SCORE correct={correct} total={CourseExerciseFixtures.Questions.Length}");
Console.WriteLine($"SICHUAN_COURSE_EXERCISE_ERRORS {string.Join(' ', errorClasses.OrderBy(item => item.Key).Select(item => $"{item.Key}={item.Value}"))}");
foreach (var strategy in new[] { "live", "types", "classic_live", "classic_types" })
{
    var strategyCorrect = CourseExerciseFixtures.Questions.Count(question =>
    {
        var ranked = strategy switch
        {
            "live" => exerciseDetails[question.Id].Candidates.OrderByDescending(item => item.LiveUkeire).ThenBy(item => item.Shanten),
            "types" => exerciseDetails[question.Id].Candidates.OrderByDescending(item => item.ImprovingTiles.Count).ThenByDescending(item => item.LiveUkeire),
            "classic_live" => exerciseDetails[question.Id].Candidates.OrderByDescending(item => item.ClassicPatternScore).ThenByDescending(item => item.LiveUkeire),
            _ => exerciseDetails[question.Id].Candidates.OrderByDescending(item => item.ClassicPatternScore).ThenByDescending(item => item.ImprovingTiles.Count).ThenByDescending(item => item.LiveUkeire)
        };
        return CourseExerciseFixtures.AnswerKey[question.Id].Contains(ranked.First().TileType);
    });
    Console.WriteLine($"SICHUAN_COURSE_STRATEGY strategy={strategy} correct={strategyCorrect} total={CourseExerciseFixtures.Questions.Length}");
}

// Generated isomorphs: changing suit labels must not change a classic type.
foreach (var fixture in classicFixtures)
{
    foreach (var shift in new[] { 1, 2 })
    {
        var rotated = fixture.Tiles.Select(tile => ((tile / 9 + shift) % 3) * 9 + tile % 9).ToArray();
        var rotatedAnalysis = classic.Analyze(SichuanTileCodec.BuildCount18(rotated));
        Require(rotatedAnalysis.Type == fixture.Expected,
            $"suit-rotated classic fixture must preserve type {fixture.Expected}, got {rotatedAnalysis.Type}");
    }
}
Console.WriteLine("SICHUAN_CLASSIC_ISOMORPH_PASS rotations=8");

Console.WriteLine("SICHUAN_COURSE_SCORING_CHECKS_PASS");

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}
