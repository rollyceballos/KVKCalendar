//
//  DayView.swift
//  KVKCalendar
//
//  Created by Sergei Kviatkovskii on 02/01/2019.
//

#if os(iOS)

import UIKit

final class DayView: UIView {
    
    private var parameters: Parameters
    private let tagEventViewer = -10
    private var timelineScale: CGFloat
    
    struct Parameters {
        var style: Style
        var data: DayData
        weak var delegate: DisplayDelegate?
        weak var dataSource: DisplayDataSource?
    }
    
    var scrollableWeekView = ScrollableWeekView(parameters: .init(frame: .zero,
                                                                  weeks: [],
                                                                  date: Date(),
                                                                  type: .day,
                                                                  style: Style()))
    
    var timelinePage = TimelinePageView(maxLimit: 0, pages: [], frame: .zero)
    
    private var topBackgroundView = UIView()
    private var isAvailableEventViewer: Bool {
        Platform.currentInterface != .phone
    }
    
    init(parameters: Parameters, frame: CGRect) {
        self.parameters = parameters
        self.timelineScale = parameters.style.timeline.scale?.min ?? 1
        super.init(frame: frame)
        setUI(reload: true)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDate(_ date: Date) {
        parameters.data.date = date
        scrollableWeekView.setDate(date)
    }
    
    func reloadData(_ events: [Event]) {
        parameters.data.recurringEvents = events.filter { $0.recurringType != .none }
        parameters.data.events = parameters.data.filterEvents(events, date: parameters.data.date)
        timelinePage.timelineView?.create(dates: [parameters.data.date],
                                          events: parameters.data.events,
                                          recurringEvents: parameters.data.recurringEvents,
                                          selectedDate: parameters.data.date)
    }
    
    func reloadEventViewerIfNeeded() {
        guard isAvailableEventViewer else { return }
        
        var defaultFrame = timelinePage.frame
        if let defaultWidth = style.timeline.widthEventViewer {
            defaultFrame.size.width = defaultWidth
        }
        updateEventViewer(frame: defaultFrame)
    }
    
    @discardableResult private func updateEventViewer(frame: CGRect) -> CGRect? {
        var viewerFrame = frame
        // hard reset the width when we change the orientation
        if UIDevice.current.orientation.isPortrait {
            viewerFrame.size.width = UIScreen.main.bounds.width * 0.5
            viewerFrame.origin.x = viewerFrame.width
        } else {
            viewerFrame.origin.x = bounds.width - viewerFrame.width
        }
        guard let eventViewer = parameters.dataSource?.willDisplayEventViewer(date: parameters.data.date, frame: viewerFrame) else { return nil }
        
        eventViewer.tag = tagEventViewer
        addSubview(eventViewer)
        return viewerFrame
    }
}

extension DayView: TimelineDelegate {
    
    func didDisplayEvents(_ events: [Event], dates: [Date?]) {
        parameters.delegate?.didDisplayEvents(events, dates: dates, type: .day)
    }
    
    func didSelectEvent(_ event: Event, frame: CGRect?) {
        parameters.delegate?.didSelectEvent(event, type: .day, frame: frame)
    }
    
    func nextDate() {
        parameters.data.date = scrollableWeekView.calculateDateWithOffset(1, needScrollToDate: true)
    }
    
    func previousDate() {
        parameters.data.date = scrollableWeekView.calculateDateWithOffset(-1, needScrollToDate: true)
    }
    
    func didResizeEvent(_ event: Event, startTime: ResizeTime, endTime: ResizeTime) {
        var startComponents = DateComponents()
        startComponents.year = event.start.year
        startComponents.month = event.start.month
        startComponents.day = event.start.day
        startComponents.hour = startTime.hour
        startComponents.minute = startTime.minute
        let startDate = style.calendar.date(from: startComponents)
        
        var endComponents = DateComponents()
        endComponents.year = event.end.year
        endComponents.month = event.end.month
        endComponents.day = event.end.day
        endComponents.hour = endTime.hour
        endComponents.minute = endTime.minute
        let endDate = style.calendar.date(from: endComponents)
        
        parameters.delegate?.didChangeEvent(event, start: startDate, end: endDate)
    }
    
    func didAddNewEvent(_ event: Event, minute: Int, hour: Int, point: CGPoint) {
        var components = DateComponents()
        components.year = parameters.data.date.year
        components.month = parameters.data.date.month
        components.day = parameters.data.date.day
        components.hour = hour
        components.minute = minute
        let date = style.calendar.date(from: components)
        parameters.delegate?.didAddNewEvent(event, date)
    }
    
    func didChangeEvent(_ event: Event, minute: Int, hour: Int, point: CGPoint, newDay: Int?) {
        var startComponents = DateComponents()
        startComponents.year = event.start.year
        startComponents.month = event.start.month
        startComponents.day = event.start.day
        startComponents.hour = hour
        startComponents.minute = minute
        let startDate = style.calendar.date(from: startComponents)
        
        let hourOffset = event.end.hour - event.start.hour
        let minuteOffset = event.end.minute - event.start.minute
        var endComponents = DateComponents()
        endComponents.year = event.end.year
        endComponents.month = event.end.month
        endComponents.day = event.end.day
        endComponents.hour = hour + hourOffset
        endComponents.minute = minute + minuteOffset
        let endDate = style.calendar.date(from: endComponents)
        
        parameters.delegate?.didChangeEvent(event, start: startDate, end: endDate)
    }
    
}

extension DayView: CalendarSettingProtocol {
    
    var style: Style {
        get {
            parameters.style
        }
        set {
            parameters.style = newValue
        }
    }
    
    func reloadFrame(_ frame: CGRect) {
        self.frame = frame
        var timelineFrame = timelinePage.frame
        
        if !style.headerScroll.isHidden {
            topBackgroundView.frame.size.width = frame.width
            scrollableWeekView.reloadFrame(frame)
            timelineFrame.size.height = frame.height - scrollableWeekView.frame.height
        } else {
            timelineFrame.size.height = frame.height
        }
        
        if isAvailableEventViewer {
            if let defaultWidth = style.timeline.widthEventViewer {
                timelineFrame.size.width = frame.width - defaultWidth
                
                if let idx = subviews.firstIndex(where: { $0.tag == tagEventViewer }) {
                    subviews[idx].removeFromSuperview()
                    var viewerFrame = timelineFrame
                    
                    let width: CGFloat
                    if UIDevice.current.orientation.isPortrait {
                        width = frame.width * 0.5
                        timelineFrame.size.width = frame.width - width
                    } else {
                        width = defaultWidth
                    }
                    
                    viewerFrame.size.width = width
                    if let resultViewerFrame = updateEventViewer(frame: viewerFrame) {
                        // notify when we did change the frame of viewer
                        parameters.delegate?.didChangeViewerFrame(resultViewerFrame)
                    }
                }
            } else {
                timelineFrame.size.width = frame.width
            }
        } else {
            timelineFrame.size.width = frame.width
        }
        
        timelinePage.frame = timelineFrame
        timelinePage.timelineView?.reloadFrame(CGRect(origin: .zero, size: timelineFrame.size))
        timelinePage.timelineView?.create(dates: [parameters.data.date],
                                          events: parameters.data.events,
                                          recurringEvents: parameters.data.recurringEvents,
                                          selectedDate: parameters.data.date)
        timelinePage.reloadCacheControllers()
    }
    
    func updateStyle(_ style: Style) {
        let reload = self.style != style
        self.style = style
        setUI(reload: reload)
        timelinePage.reloadPages()
        reloadFrame(frame)
        reloadEventViewerIfNeeded()
    }
    
    func setUI(reload: Bool) {
        subviews.forEach { $0.removeFromSuperview() }
        
        if !parameters.style.headerScroll.isHidden {
            if reload {
                topBackgroundView = setupTopBackgroundView()
                scrollableWeekView = setupScrollableWeekView()
            }
            
            addSubview(topBackgroundView)
            topBackgroundView.addSubview(scrollableWeekView)
        }
        
        if reload {
            timelinePage = setupTimelinePageView()
        }
        addSubview(timelinePage)
        timelinePage.isPagingEnabled = style.timeline.scrollDirections.contains(.horizontal)
    }
    
    private func createTimelineView(frame: CGRect) -> TimelineView {
        var viewFrame = frame
        viewFrame.origin = .zero
        
        let view = TimelineView(parameters: .init(style: style, type: .day, scale: timelineScale), frame: viewFrame)
        view.delegate = self
        view.dataSource = parameters.dataSource
        view.deselectEvent = { [weak self] (event) in
            self?.parameters.delegate?.didDeselectEvent(event, animated: true)
        }
        view.didChangeScale = { [weak self] (newScale) in
            if newScale != self?.timelineScale {
                self?.timelineScale = newScale
            }
        }
        return view
    }
    
    private func setupTimelinePageView() -> TimelinePageView {
        var timelineFrame = frame
        
        if !style.headerScroll.isHidden {
            timelineFrame.origin.y = scrollableWeekView.frame.height
            timelineFrame.size.height -= scrollableWeekView.frame.height
        }
        
        if isAvailableEventViewer {
            if UIDevice.current.orientation.isPortrait {
                timelineFrame.size.width = UIScreen.main.bounds.width * 0.5
            } else {
                timelineFrame.size.width -= style.timeline.widthEventViewer ?? 0
            }
        }
        
        let timelineViews = Array(0..<style.timeline.maxLimitCachedPages).reduce([]) { (acc, _) -> [TimelineView] in
            acc + [createTimelineView(frame: timelineFrame)]
        }
        let page = TimelinePageView(maxLimit: style.timeline.maxLimitCachedPages,
                                    pages: timelineViews,
                                    frame: timelineFrame)
        
        page.didSwitchTimelineView = { [weak self] (_, type) in
            guard let self = self else { return }
            
            let newTimeline = self.createTimelineView(frame: timelineFrame)
            
            switch type {
            case .next:
                self.nextDate()
                self.timelinePage.addNewTimelineView(newTimeline, to: .end)
            case .previous:
                self.previousDate()
                self.timelinePage.addNewTimelineView(newTimeline, to: .begin)
            }
            
            self.parameters.delegate?.didSelectDates([self.parameters.data.date], type: .day, frame: nil)
        }
        
        page.willDisplayTimelineView = { [weak self] (timeline, type) in
            guard let self = self else { return }
            
            let nextDate: Date?
            switch type {
            case .next:
                nextDate = self.style.calendar.date(byAdding: .day,
                                                    value: 1,
                                                    to: self.parameters.data.date)
            case .previous:
                nextDate = self.style.calendar.date(byAdding: .day,
                                                    value: -1,
                                                    to: self.parameters.data.date)
            }
            
            timeline.create(dates: [nextDate],
                            events: self.parameters.data.events,
                            recurringEvents: self.parameters.data.recurringEvents,
                            selectedDate: self.parameters.data.date)
        }
        
        return page
    }
    
    private func setupScrollableWeekView() -> ScrollableWeekView {
        let heightView: CGFloat
        if style.headerScroll.isHiddenSubview {
            heightView = style.headerScroll.heightHeaderWeek
        } else {
            heightView = style.headerScroll.heightHeaderWeek + style.headerScroll.heightSubviewHeader
        }
        let view = ScrollableWeekView(parameters: .init(frame: CGRect(x: 0, y: 0,
                                                                      width: frame.width,
                                                                      height: heightView),
                                                        weeks: parameters.data.daysBySection,
                                                        date: parameters.data.date,
                                                        type: .day,
                                                        style: style))
        view.dataSource = parameters.dataSource
        view.didSelectDate = { [weak self] (date, type) in
            if let item = date {
                self?.parameters.data.date = item
                self?.parameters.delegate?.didSelectDates([item], type: type, frame: nil)
            }
        }
        view.didTrackScrollOffset = { [weak self] (offset, stop) in
            self?.timelinePage.timelineView?.moveEvents(offset: offset, stop: stop)
        }
        view.didChangeDay = { [weak self] (type) in
            guard let self = self else { return }
            
            self.timelinePage.changePage(type)
            let newTimeline = self.createTimelineView(frame: CGRect(origin: .zero,
                                                                    size: self.timelinePage.bounds.size))
            
            switch type {
            case .next:
                self.timelinePage.addNewTimelineView(newTimeline, to: .end)
            case .previous:
                self.timelinePage.addNewTimelineView(newTimeline, to: .begin)
            }
        }
        return view
    }
    
    private func setupTopBackgroundView() -> UIView {
        let heightView: CGFloat
        if style.headerScroll.isHiddenSubview {
            heightView = style.headerScroll.heightHeaderWeek
        } else {
            heightView = style.headerScroll.heightHeaderWeek + style.headerScroll.heightSubviewHeader
        }
        let view = UIView(frame: CGRect(x: 0, y: 0, width: frame.width, height: heightView))
        if let blur = style.headerScroll.backgroundBlurStyle {
            view.setBlur(style: blur)
        } else {
            view.backgroundColor = style.headerScroll.colorBackground
        }
        return view
    }
}

#endif
