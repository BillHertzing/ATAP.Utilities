"""
Wall Clock Animation Scene
Renders a 24-hour wall clock compressed into 30 seconds with smooth rotating hands.
Library scene for reusable clock animation components.
"""
from manim import *
import math


class WallClockScene(Scene):
    """
    A reusable library scene that renders a wall clock with:
    - Arabic numerals at all 12 hour positions
    - Tick marks at all 12 positions
    - Two animated hands (hour and minute)
    - An AM/PM indicator on the clock face
    - A 31-day calendar view with daily strike marks
    - A light-blue windowToTheOutside to the left of the calendar
    - 96-hour cycle compressed to 30 seconds
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Configuration defaults
        self.video_duration = 30  # seconds
        self.fps = 60  # frames per second
        self.compression_ratio = 24 * 60 * 60  # 24 hours in seconds
        self.clock_radius = 3
        self.clock_scale = 0.2125
        self.calendar_relative_height = 1.0
        self.window_width_multiplier = 1.3225
        self.window_height_multiplier = 1.1
        self.clock_center = RIGHT * 2.7 + UP * 0.65
        self.calendar_clock_gap = 0.14
        self.window_calendar_gap = 0.03
        self.start_time_hours = 8
        self.wall_padding = 0.45

    def construct(self):
        """Construct the clock animation scene."""
        # Fade in the scene
        self.camera.background_color = "#1a1a1a"  # Dark background

        # Create clock elements
        clock_face = self.create_clock_face()
        hour_hand = self.create_hour_hand()
        minute_hand = self.create_minute_hand()
        calendar_group, day_boxes = self.create_calendar()
        time_tracker = ValueTracker(self.start_time_hours)

        # Start the clock at 8:00 AM.
        hour_hand.rotate(
            -(self.start_time_hours % 12) * (2 * PI / 12),
            about_point=ORIGIN,
        )

        # Group all clock elements
        clock_group = VGroup(clock_face, hour_hand, minute_hand)
        clock_group.scale(self.clock_scale)
        clock_group.move_to(self.clock_center)
        am_pm_indicator = self.create_am_pm_indicator(time_tracker)

        calendar_group.scale_to_fit_height(clock_group.height * self.calendar_relative_height)
        calendar_group.next_to(clock_group, LEFT, buff=self.calendar_clock_gap)
        calendar_group.move_to(
            [calendar_group.get_center()[0], clock_group.get_center()[1], 0]
        )

        calendar_clock_group = VGroup(calendar_group, clock_group, am_pm_indicator)
        window_to_the_outside = self.create_window_to_the_outside(calendar_clock_group, time_tracker)
        wall_section = self.create_wall_section(window_to_the_outside, calendar_clock_group)

        day_marks = [self.create_day_strike_mark(day_boxes[day]) for day in range(1, 5)]

        # Fade in
        scene_group = VGroup(wall_section, window_to_the_outside, calendar_group, clock_group, am_pm_indicator)
        self.add(scene_group)
        self.play(FadeIn(scene_group), run_time=1)

        # Animate the hands through four 24-hour phases (96 total hours).
        mark_duration = 0.5
        total_phase_count = 4
        phase_duration = (
            self.video_duration - 2 - (total_phase_count * mark_duration)
        ) / total_phase_count

        for day_mark in day_marks:
            self.play(
                Rotate(
                    hour_hand,
                    angle=-4 * PI,
                    about_point=self.clock_center,
                    rate_func=linear,
                ),
                Rotate(
                    minute_hand,
                    angle=-48 * PI,
                    about_point=self.clock_center,
                    rate_func=linear,
                ),
                time_tracker.animate.increment_value(24),
                run_time=phase_duration,
            )
            self.play(Create(day_mark), run_time=mark_duration)

        # Fade out
        self.play(FadeOut(VGroup(scene_group, *day_marks)), run_time=1)

    def create_clock_face(self):
        """Create the clock face with Arabic numerals and tick marks."""
        circle = Circle(radius=self.clock_radius, color=WHITE, stroke_width=3)
        circle.set_fill(color="#f0f0f0", opacity=0.1)

        # Create tick marks and Arabic numerals
        clock_elements = [circle]

        numeral_distance = self.clock_radius - 0.55
        for hour in range(1, 13):
            angle = (PI / 2) - (hour % 12) * (2 * PI / 12)
            x = numeral_distance * math.cos(angle)
            y = numeral_distance * math.sin(angle)
            text = Text(
                str(hour),
                font_size=24,
                color=WHITE,
                weight=BOLD
            )
            text.move_to((x, y, 0))
            clock_elements.append(text)

        # Add tick marks at all 12 positions
        for i in range(12):
            angle = i * (2 * PI / 12) - PI / 2  # Start from top (12 o'clock)

            # Outer and inner radius for tick mark
            outer_x = self.clock_radius * math.cos(angle)
            outer_y = self.clock_radius * math.sin(angle)

            inner_distance = self.clock_radius - 0.3
            inner_x = inner_distance * math.cos(angle)
            inner_y = inner_distance * math.sin(angle)

            tick = Line(
                (inner_x, inner_y, 0),
                (outer_x, outer_y, 0),
                color=WHITE,
                stroke_width=2
            )
            clock_elements.append(tick)

        return VGroup(*clock_elements)

    def create_calendar(self):
        """Create a 31-day month view starting on Wednesday."""
        day_boxes = {}
        calendar_elements = []
        box_size = 0.6
        gap = 0.08
        columns = 7
        start_weekday = 3  # Sunday=0, Wednesday=3
        rows = 5  # 31 days starting on Wednesday requires 5 rows.

        weekday_labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        for col, label in enumerate(weekday_labels):
            x = (col - ((columns - 1) / 2)) * (box_size + gap)
            y = ((rows / 2) * (box_size + gap)) + 0.45
            header = Text(label, font_size=18, color=WHITE, weight=BOLD)
            header.move_to((x, y, 0))
            calendar_elements.append(header)

        for slot in range(rows * columns):
            row = slot // columns
            col = slot % columns
            x = (col - ((columns - 1) / 2)) * (box_size + gap)
            y = (((rows - 1) / 2) - row) * (box_size + gap)

            rect = Square(side_length=box_size, color=WHITE, stroke_width=1.5)
            rect.move_to((x, y, 0))

            day = slot - start_weekday + 1
            if 1 <= day <= 31:
                rect.set_fill(color=WHITE, opacity=0.04)
                label = Text(str(day), font_size=18, color=WHITE)
                label.move_to((x, y, 0))
                day_group = VGroup(rect, label)
                day_boxes[day] = day_group
                calendar_elements.append(day_group)
            else:
                rect.set_stroke(color=GRAY_B, opacity=0.35)
                rect.set_fill(color=BLACK, opacity=0)
                calendar_elements.append(rect)

        return VGroup(*calendar_elements), day_boxes

    def create_window_to_the_outside(self, calendar_clock_group, time_tracker):
        """Create an animated day/night window rectangle just left of the calendar."""

        def build_window():
            height = calendar_clock_group.height * 4.0
            width = calendar_clock_group.width * self.window_width_multiplier
            left_edge_x = calendar_clock_group.get_left()[0] - self.window_calendar_gap - (width / 2)
            center_y = calendar_clock_group.get_center()[1] - (0.3 * height)

            top_color, bottom_color = self.get_window_gradient_colors(time_tracker.get_value())
            strip_count = 18
            strip_height = height / strip_count
            strips = []
            for index in range(strip_count):
                blend = index / max(strip_count - 1, 1)
                strip_color = interpolate_color(top_color, bottom_color, blend)
                strip = Rectangle(
                    width=width,
                    height=strip_height + 0.002,
                    stroke_width=0,
                )
                strip.set_fill(color=strip_color, opacity=0.95)
                strip.move_to(
                    (
                        left_edge_x,
                        center_y + (height / 2) - ((index + 0.5) * strip_height),
                        0,
                    )
                )
                strips.append(strip)

            curtain_color = ManimColor('#b68d6a')
            curtain_shadow = ManimColor('#8d6b50')
            curtain_highlight = ManimColor('#d2b092')
            rod_color = ManimColor('#ddd6c8')
            curtain_width = width * 0.16
            curtain_inset = width * 0.015
            curtain_height = height * 0.94
            curtain_fold_count = 6

            def build_curtain(center_x, trim_on_left):
                curtain = Rectangle(
                    width=curtain_width,
                    height=curtain_height,
                    stroke_width=0,
                )
                curtain.set_fill(color=curtain_color, opacity=0.92)
                curtain.move_to((center_x, center_y, 0.1))

                folds = []
                fold_spacing = curtain_width / (curtain_fold_count + 1)
                for fold_index in range(curtain_fold_count):
                    fold_x = center_x - (curtain_width / 2) + ((fold_index + 1) * fold_spacing)
                    fold = Line(
                        (fold_x, center_y + (curtain_height / 2), 0.2),
                        (fold_x, center_y - (curtain_height / 2), 0.2),
                        color=curtain_shadow if fold_index % 2 == 0 else curtain_highlight,
                        stroke_width=1.8,
                    )
                    folds.append(fold)

                trim_x = center_x - (curtain_width / 2) + 0.01 if trim_on_left else center_x + (curtain_width / 2) - 0.01
                trim = Line(
                    (trim_x, center_y + (curtain_height / 2), 0.21),
                    (trim_x, center_y - (curtain_height / 2), 0.21),
                    color=curtain_highlight,
                    stroke_width=1.5,
                )

                return VGroup(curtain, *folds, trim)

            rod = Line(
                (left_edge_x - (width / 2), center_y + (height / 2), 0.18),
                (left_edge_x + (width / 2), center_y + (height / 2), 0.18),
                color=rod_color,
                stroke_width=3,
            )

            left_curtain_center_x = left_edge_x - (width / 2) + curtain_inset + (curtain_width / 2)
            right_curtain_center_x = left_edge_x + (width / 2) - curtain_inset - (curtain_width / 2)
            left_curtain = build_curtain(left_curtain_center_x, trim_on_left=False)
            right_curtain = build_curtain(right_curtain_center_x, trim_on_left=True)

            border = Rectangle(
                width=width,
                height=height,
                color=WHITE,
                stroke_width=2,
            )
            border.set_fill(opacity=0)
            border.move_to((left_edge_x, center_y, 0))

            return VGroup(*strips, rod, left_curtain, right_curtain, border)

        return always_redraw(build_window)

    def create_wall_section(self, window_group, calendar_clock_group):
        """Create a wall section behind the window and clock/calendar unit."""
        combined = VGroup(window_group, calendar_clock_group)
        wall = RoundedRectangle(
            corner_radius=0.08,
            width=combined.width + (2 * self.wall_padding),
            height=combined.height + (2 * self.wall_padding),
            color=ManimColor('#d6c6ad'),
            stroke_width=2,
        )
        wall.set_fill(color=ManimColor('#bda98b'), opacity=0.28)
        wall.move_to(combined.get_center())
        return wall

    def create_am_pm_indicator(self, time_tracker):
        """Create a small AM/PM indicator box on the lower half of the clock."""

        def build_indicator():
            label_text = 'AM' if (time_tracker.get_value() % 24) < 12 else 'PM'
            label = Text(label_text, font_size=4.5, color=WHITE, weight=BOLD)
            rect = SurroundingRectangle(label, color=WHITE, buff=0.04, corner_radius=0.015)
            rect.set_fill(color=BLACK, opacity=0.45)
            rect.set_stroke(width=1.0)
            indicator = VGroup(rect, label)
            indicator.move_to(
                self.clock_center + DOWN * (self.clock_radius * self.clock_scale * 0.5)
            )
            return indicator

        return always_redraw(build_indicator)

    def get_window_gradient_colors(self, total_hours):
        """Return the top and bottom sky colors for the window at a given time."""
        bright_top = ManimColor('#5bc0ff')
        day_bottom = ManimColor('#4b9cd3')
        black = BLACK

        hour = total_hours % 24
        if 6 <= hour < 17:
            return bright_top, day_bottom
        if 17 <= hour < 19:
            blend = (hour - 17) / 2
            return (
                interpolate_color(bright_top, black, blend),
                interpolate_color(day_bottom, black, blend),
            )
        if 19 <= hour or hour < 5:
            return black, black

        blend = hour - 5
        return (
            interpolate_color(black, bright_top, blend),
            interpolate_color(black, day_bottom, blend),
        )

    def create_day_strike_mark(self, day_group):
        """Create an X mark over a calendar day box."""
        rect = day_group[0]
        inset = 0.08
        top_left = rect.get_corner(UL) + RIGHT * inset + DOWN * inset
        top_right = rect.get_corner(UR) + LEFT * inset + DOWN * inset
        bottom_left = rect.get_corner(DL) + RIGHT * inset + UP * inset
        bottom_right = rect.get_corner(DR) + LEFT * inset + UP * inset

        slash_a = Line(top_left, bottom_right, color=RED_E, stroke_width=4)
        slash_b = Line(top_right, bottom_left, color=RED_E, stroke_width=4)
        return VGroup(slash_a, slash_b)

    def create_hour_hand(self):
        """Create the hour hand (white, shorter)."""
        hand = Line(
            (0, 0, 0),
            (0, 1.2, 0),  # 40% of radius
            color=WHITE,
            stroke_width=8
        )
        hand.set_stroke(color=WHITE, width=8, opacity=1)

        # Add arrow cap for visibility
        tip = Triangle(color=WHITE, stroke_width=0, fill_opacity=1)
        tip.scale(0.15)
        tip.move_to((0, 1.2, 0))
        tip.rotate(PI / 2)

        return VGroup(hand, tip)

    def create_minute_hand(self):
        """Create the minute hand (white, medium length)."""
        hand = Line(
            (0, 0, 0),
            (0, 2.1, 0),  # 70% of radius
            color=WHITE,
            stroke_width=6
        )
        hand.set_stroke(color=WHITE, width=6, opacity=1)

        # Add arrow cap
        tip = Triangle(color=WHITE, stroke_width=0, fill_opacity=1)
        tip.scale(0.12)
        tip.move_to((0, 2.1, 0))
        tip.rotate(PI / 2)

        return VGroup(hand, tip)

class WallClockSceneHD(WallClockScene):
    """
    1080p @ 60fps variant of WallClockScene.
    Inherits all functionality and sets video configuration.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fps = 60
        self.video_duration = 30
