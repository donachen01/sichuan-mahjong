namespace SichuanMahjong.AI.Core.CourseChecks;

internal sealed record CourseExerciseQuestion(string Id, int ClassicType, int[] Tiles);

internal static class CourseExerciseFixtures
{
    private static int T(int rank) => rank - 1;
    private static int P(int rank) => 9 + rank - 1;
    private static int W(int rank) => 18 + rank - 1;

    // Inputs transcribed from the answer-free question frames. Answers live in
    // a separate key below and are not passed to the decision engine.
    public static readonly CourseExerciseQuestion[] Questions =
    [
        new("22-1", 1, [T(1),T(2),T(3),T(4),T(5),T(6),T(7),W(1),W(2),W(3),W(3),W(4),W(7),W(8)]),
        new("22-2", 1, [W(3),W(4),W(5),W(5),W(6),W(7),W(8),P(1),P(2),P(5),P(6),P(7),P(8),P(9)]),
        new("22-3", 1, [W(1),W(2),W(3),W(3),W(4),W(7),W(8),W(9),T(1),T(2),T(4),T(6),T(7),T(7)]),
        new("22-4", 1, [P(1),P(2),P(3),P(4),P(5),T(1),T(1),T(2),T(3),T(5),T(6),T(7),T(8),T(9)]),
        new("22-5", 1, [W(2),W(2),W(2),W(3),W(4),W(5),W(5),W(7),W(8),W(9),T(1),T(2),T(7),T(8)]),

        new("23-1", 2, [W(4),W(5),W(6),W(7),W(7),W(8),T(1),T(1),T(2),T(3),T(5),T(6),T(7),T(8)]),
        new("23-2", 2, [W(2),W(2),W(3),W(4),W(4),W(5),P(1),P(1),P(2),P(3),P(5),P(6),P(6),P(6)]),
        new("23-3", 2, [W(3),W(4),W(4),W(5),W(6),W(7),W(7),W(8),T(1),T(2),T(3),T(6),T(7),T(9)]),
        new("23-4", 2, [P(2),P(2),P(2),P(3),P(5),P(5),P(6),P(6),T(3),T(6),T(6),T(7),T(8),T(8)]),
        new("23-5", 2, [P(1),P(2),P(3),P(3),P(5),P(5),P(6),P(7),T(2),T(3),T(4),T(5),T(7),T(8)]),

        new("24-1", 3, [W(2),W(3),W(4),W(4),W(5),W(5),W(5),W(8),W(8),P(2),P(3),P(5),P(6),P(6)]),
        new("24-2", 3, [W(3),W(3),W(3),W(4),W(4),W(5),T(1),T(1),T(3),T(4),T(5),T(7),T(8),T(9)]),
        new("24-3", 3, [W(4),W(4),W(5),W(5),W(5),W(6),W(8),W(8),T(2),T(3),T(5),T(6),T(6),T(6)]),
        new("24-4", 3, [P(2),P(3),P(5),P(6),T(1),T(2),T(3),T(4),T(5),T(5),T(6),T(7),T(8),T(9)]),
        new("24-5", 3, [P(2),P(3),P(4),P(4),P(5),P(5),P(6),P(8),T(2),T(3),T(4),T(5),T(7),T(8)]),

        new("25-1", 4, [W(3),W(4),W(4),W(5),W(6),W(7),T(1),T(1),T(3),T(3),T(5),T(7),T(8),T(9)]),
        new("25-2", 4, [W(3),W(3),W(3),W(4),W(4),W(5),T(1),T(1),T(4),T(4),T(5),T(7),T(8),T(9)]),
        new("25-3", 4, [W(4),W(4),W(6),W(6),W(8),W(8),T(1),T(2),T(3),T(4),T(5),T(7),T(8),T(9)]),
        new("25-4", 4, [P(1),P(2),P(3),P(4),P(4),W(2),W(2),W(2),W(3),W(3),W(4),W(7),W(8),W(8)]),
        new("25-5", 4, [P(1),P(1),P(1),P(2),P(3),P(5),P(5),P(7),W(2),W(2),W(2),W(2),W(3),W(4)]),
    ];

    public static readonly IReadOnlyDictionary<string, int[]> AnswerKey = new Dictionary<string, int[]>
    {
        ["22-1"]=[T(2),T(5)], ["22-2"]=[W(5)], ["22-3"]=[T(7)], ["22-4"]=[T(1)], ["22-5"]=[W(5)],
        ["23-1"]=[T(1)], ["23-2"]=[W(4)], ["23-3"]=[W(4),W(7)], ["23-4"]=[T(6)], ["23-5"]=[P(3),P(7)],
        ["24-1"]=[W(4)], ["24-2"]=[W(4)], ["24-3"]=[T(6)], ["24-4"]=[P(5)], ["24-5"]=[P(8)],
        ["25-1"]=[W(4)], ["25-2"]=[T(4)], ["25-3"]=[W(6)], ["25-4"]=[W(8)], ["25-5"]=[P(7)],
    };
}
