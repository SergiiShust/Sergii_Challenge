package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Custom types to handle specific JSON transformations
type DataType struct {
	S    string              `json:"S,omitempty"`
	N    string              `json:"N,omitempty"`
	BOOL string              `json:"BOOL,omitempty"`
	NULL string              `json:"NULL,omitempty"`
	L    interface{}         `json:"L,omitempty"`
	M    map[string]DataType `json:"M,omitempty"`
}

type OutputType map[string]interface{}

func main() {
	// Sample input JSON
	inputJSON := `
	{
		"number_1": {"N": "1.50"},
		"string_1": {"S": "784498 "},
		"string_2": {"S": "2014-07-16T20:55:46Z"},
		"map_1": {
			"M": {
				"bool_1": {"BOOL": "truthy"},
				"null_1": {"NULL ": "true"},
				"list_1": {"L": [{"S": ""}, {"N": "011"}, {"N": "5215s"}, {"BOOL": "f"}, {"NULL": "0"}]}
			}
		},
		"list_2": {"L": "noop"},
		"list_3": {"L": ["noop"]},
		"": {"S": "noop"}
	}`

	// Parse JSON input
	var input map[string]DataType
	if err := json.Unmarshal([]byte(inputJSON), &input); err != nil {
		fmt.Println("Error parsing JSON:", err)
		return
	}

	// Transform input to the desired output format
	output := transform(input)

	// Print the result in JSON format
	resultJSON, _ := json.MarshalIndent(output, "", "  ")
	fmt.Println(string(resultJSON))
}

func transform(input map[string]DataType) []OutputType {
	output := OutputType{}

	for k, v := range input {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}

		value := transformDataType(v)
		if value != nil {
			output[key] = value
		}
	}

	return []OutputType{output}
}

func transformDataType(dt DataType) interface{} {
	if dt.S != "" {
		return transformString(dt.S)
	}
	if dt.N != "" {
		return transformNumber(dt.N)
	}
	if dt.BOOL != "" {
		return transformBoolean(dt.BOOL)
	}
	if dt.NULL != "" {
		return transformNull(dt.NULL)
	}
	if dt.L != nil {
		return transformList(dt.L)
	}
	if dt.M != nil {
		return transformMap(dt.M)
	}
	return nil
}

func transformString(s string) interface{} {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}

	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.Unix()
	}

	return s
}

func transformNumber(n string) interface{} {
	n = strings.TrimSpace(n)
	if n == "" {
		return nil
	}

	// Remove leading zeros
	trimmedNum := regexp.MustCompile(`^0+`).ReplaceAllString(n, "")
	if f, err := strconv.ParseFloat(trimmedNum, 64); err == nil {
		return f
	}

	return nil
}

func transformBoolean(b string) interface{} {
	b = strings.TrimSpace(strings.ToLower(b))
	switch b {
	case "1", "t", "true":
		return true
	case "0", "f", "false":
		return false
	}
	return nil
}

func transformNull(nullVal string) interface{} {
	nullVal = strings.TrimSpace(strings.ToLower(nullVal))
	if nullVal == "1" || nullVal == "t" || nullVal == "true" {
		return nil
	}
	return nil
}

func transformList(list interface{}) interface{} {
	listSlice, ok := list.([]interface{})
	if !ok {
		return nil // Skip if L is not a slice
	}

	var resultList []interface{}

	for _, item := range listSlice {
		dt, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		data := DataType{}
		mapToStruct(dt, &data)
		transformed := transformDataType(data)
		if transformed != nil {
			resultList = append(resultList, transformed)
		}
	}

	if len(resultList) == 0 {
		return nil
	}

	return resultList
}

func transformMap(m map[string]DataType) interface{} {
	resultMap := OutputType{}

	for k, v := range m {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}

		value := transformDataType(v)
		if value != nil {
			resultMap[key] = value
		}
	}

	if len(resultMap) == 0 {
		return nil
	}

	return resultMap
}

// Helper function to map JSON to struct for nested transformations
func mapToStruct(m map[string]interface{}, dt *DataType) {
	for k, v := range m {
		switch k {
		case "S":
			dt.S, _ = v.(string)
		case "N":
			dt.N, _ = v.(string)
		case "BOOL":
			dt.BOOL, _ = v.(string)
		case "NULL":
			dt.NULL, _ = v.(string)
		case "L":
			dt.L = v
		case "M":
			subMap, ok := v.(map[string]interface{})
			if ok {
				dt.M = make(map[string]DataType)
				for sk, sv := range subMap {
					subData := DataType{}
					mapToStruct(sv.(map[string]interface{}), &subData)
					dt.M[sk] = subData
				}
			}
		}
	}
}
