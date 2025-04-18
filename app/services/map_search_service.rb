# typed: true
# frozen_string_literal: true

class MapSearchService
  extend T::Sig

  sig { params(query: String).void }
  def initialize(query)
    @query = query.downcase
    @terms = @query.split
  end

  sig { returns(T::Array[String]) }
  def search
    return [] if @query.empty?

    maps = MapUpload.available_maps

    # Exact matches
    exact_matches = maps.select { |map| map.downcase == @query }
    return exact_matches if exact_matches.any?

    # Get all league maps for reference
    league_maps = LeagueMaps.all_league_maps

    # Partial matches with ranking
    matches = maps.map do |map|
      score = calculate_score(map.downcase, league_maps)
      [ map, score ]
    end

    matches.select { |_, score| score > 0 }
           .sort_by { |_, score| -score }
           .map(&:first)
           .first(10)
  end

  private

  # --- Main Scoring Logic ---

  sig { params(map: String, league_maps: T::Array[String]).returns(Float) }
  def calculate_score(map, league_maps)
    map_terms = map.split("_")

    # Initial check: Does any query term relate to this map at all?
    return 0.0 unless query_term_matches_map?(map, map_terms)

    map_name_no_prefix = map_terms[1..-1]&.join("_").to_s
    total_score = 0.0

    total_score += calculate_league_bonus(map, league_maps)
    total_score += calculate_exact_term_bonus(map)
    total_score += calculate_prefix_bonus(map_terms)
    total_score += calculate_map_name_bonus(map_name_no_prefix)
    total_score += calculate_version_bonus(map)
    total_score += calculate_fuzzy_partial_score(map_terms)

    total_score
  end

  # --- Gatekeeping Check ---

  sig { params(map: String, map_terms: T::Array[String]).returns(T::Boolean) }
  def query_term_matches_map?(map, map_terms)
    @terms.any? do |term|
      # Check for inclusion in full map name first
      next true if map.include?(term)

      # Then check for fuzzy match against parts using term-length dependent distance
      max_allowed_match_distance = case term.length
      when 0..5 then 1
      when 6..8 then 2
      else 3
      end

      map_terms.any? do |part|
        distance = levenshtein_distance(term, part)
        distance <= max_allowed_match_distance
      end
    end
  end

  # --- Scoring Helper Methods ---

  sig { params(map: String, league_maps: T::Array[String]).returns(Float) }
  def calculate_league_bonus(map, league_maps)
    league_maps.include?(map) ? 70.0 : 0.0
  end

  sig { params(map: String).returns(Float) }
  def calculate_exact_term_bonus(map)
    # Bonus for each query term found anywhere in the map name
    @terms.count { |term| map.include?(term) } * 40.0
  end

  sig { params(map_terms: T::Array[String]).returns(Float) }
  def calculate_prefix_bonus(map_terms)
    # Bonus if the first query term matches the map prefix (e.g., cp_, koth_)
    @terms.first == map_terms.first ? 40.0 : 0.0
  end

  sig { params(map_name_no_prefix: String).returns(Float) }
  def calculate_map_name_bonus(map_name_no_prefix)
    # Significant bonus if query terms (after first) exactly match the map name without prefix
    query_name = @terms[1..-1]&.join("_")
    (@terms.length > 1 && map_name_no_prefix == query_name) ? 100.0 : 0.0
  end

  sig { params(map: String).returns(Float) }
  def calculate_version_bonus(map)
    score = 0.0
    if map =~ /_f\d+/
      if (match = map.match(/_f(\d+)/))
        version_num = match[1].to_i
        score += 30 + version_num
      end
    elsif map.include?("final")
      score += 20
    elsif map.include?("pro") || map =~ /_rc\d+/
      score += 10
    end
    score
  end

  sig { params(map_terms: T::Array[String]).returns(Float) }
  def calculate_fuzzy_partial_score(map_terms)
    score = 0.0
    @terms.each do |term|
      map_terms.each do |part|
        # Skip prefix matches as they're handled by calculate_prefix_bonus
        next if part == map_terms.first && [ "cp", "koth" ].include?(part)

        distance = levenshtein_distance(term, part)
        max_length = [ term.length, part.length ].max

        # Fuzzy scoring based on term length
        max_allowed_score_distance = case term.length
        when 0..5 then 1
        when 6..8 then 2
        else 3
        end
        if distance <= max_allowed_score_distance && distance > 0
          similarity_score = 1.0 - (distance.to_f / max_length)
          score += 30 * similarity_score
        end

        # Partial matching score (only if not exact part match)
        if (part.include?(term) || term.include?(part)) && distance > 0
          score += 15
        end
      end
    end
    score
  end

  # --- Levenshtein Distance Calculation ---

  sig { params(str1: String, str2: String).returns(Integer) }
  def levenshtein_distance(str1, str2)
    m = str1.length
    n = str2.length
    return m if n == 0
    return n if m == 0

    matrix = Array.new(m + 1) { Array.new(n + 1) }

    (0..m).each { |i| matrix[i][0] = i }
    (0..n).each { |j| matrix[0][j] = j }

    (1..n).each do |j|
      (1..m).each do |i|
        if str1[i - 1] == str2[j - 1]
          matrix[i][j] = matrix[i - 1][j - 1]
        else
          matrix[i][j] = [
            matrix[i - 1][j],
            matrix[i][j - 1],
            matrix[i - 1][j - 1]
          ].min + 1
        end
      end
    end

    matrix[m][n]
  end
end
