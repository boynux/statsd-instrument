module StatsD::Instrument::Assertions

  def capture_statsd_calls(&block)
    mock_backend = StatsD::Instrument::Backends::CaptureBackend.new
    old_backend, StatsD.backend = StatsD.backend, mock_backend
    block.call
    mock_backend.collected_metrics
  ensure
    if old_backend.kind_of?(StatsD::Instrument::Backends::CaptureBackend)
      old_backend.collected_metrics.concat(mock_backend.collected_metrics)
    end

    StatsD.backend = old_backend
  end

  def assert_no_statsd_calls(metric_name = nil, &block)
    metrics = capture_statsd_calls(&block)
    metrics.select! { |m| m.name == metric_name } if metric_name
    assert metrics.empty?, "No StatsD calls for metric #{metric_name} expected."
  end

  def assert_statsd_increment(metric_name, options = {}, &block)
    assert_statsd_call(:c, metric_name, options, &block)
  end

  def assert_statsd_measure(metric_name, options = {}, &block)
    assert_statsd_call(:ms, metric_name, options, &block)
  end

  def assert_statsd_gauge(metric_name, options = {}, &block)
    assert_statsd_call(:g, metric_name, options, &block)
  end

  def assert_statsd_histogram(metric_name, options = {}, &block)
    assert_statsd_call(:h, metric_name, options, &block)
  end

  def assert_statsd_set(metric_name, options = {}, &block)
    assert_statsd_call(:s, metric_name, options, &block)
  end

  def assert_statsd_key_value(metric_name, options = {}, &block)
    assert_statsd_call(:kv, metric_name, options, &block)
  end

  private

  def assert_statsd_call(metric_type, metric_name, options = {}, &block)
    options[:times] ||= 1
    metrics = capture_statsd_calls(&block)
    metrics = metrics.select { |m| m.type == metric_type && m.name == metric_name }
    assert metrics.length > 0, "No StatsD calls for metric #{metric_name} were made."
    assert options[:times] === metrics.length, "The amount of StatsD calls for metric #{metric_name} was unexpected. Expected #{options[:times].inspect}, found #{metrics.length}"
    metric = metrics.first

    assert_equal options[:sample_rate], metric.sample_rate, "Unexpected value submitted for StatsD metric #{metric_name}" if options[:sample_rate]
    assert_equal options[:value], metric.value, "Unexpected StatsD sample rate for metric #{metric_name}" if options[:value]
    assert_equal Set.new(StatsD::Instrument::Metric.normalize_tags(options[:tags])), Set.new(metric.tags), "Unexpected StatsD tags for metric #{metric_name}" if options[:tags]

    metric
  end
end
