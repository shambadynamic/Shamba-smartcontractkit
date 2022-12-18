//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/ShambaChainSelector.sol";

contract ShambaGeoConsumer is ChainlinkClient, ShambaChainSelector {
    using Chainlink for Chainlink.Request;
    ShambaChainSelector shambaChainSelector;
    int256 private geostats_data;
    string private cid;
    uint256 public total_oracle_calls = 0;

    mapping(uint256 => string) private cids;

    struct Geometry {
        uint8 property_id;
        string coordinates;
    }

    mapping(uint8 => string) geometry_map;

    function getGeometry(uint8 property_id)
        public
        view
        returns (string memory)
    {
        return geometry_map[property_id];
    }

    function getCid(uint256 index) public view returns (string memory) {
        return cids[index];
    }

    constructor(uint64 chain_id) ShambaChainSelector(chain_id) {
        shambaChainSelector = new ShambaChainSelector(chain_id);
        setChainlinkToken(shambaChainSelector.linkTokenContractAddress());
        setChainlinkOracle(shambaChainSelector.operatorAddress());
    }

    function concat(string memory a, string memory b)
        private
        pure
        returns (string memory)
    {
        return (string(abi.encodePacked(a, "", b)));
    }

    function requestGeostatsData(
        string memory agg_x,
        string memory dataset_code,
        string memory selected_band,
        string memory image_scale,
        string memory start_date,
        string memory end_date,
        Geometry[] memory geometry
    ) public {

        Chainlink.Request memory req = buildChainlinkRequest(
            shambaChainSelector.jobSpecId("geo-statistics"),
            address(this),
            this.fulfillGeostatsData.selector
        );

        string memory concatenated_data = concat('{"agg_x":"', agg_x);

        concatenated_data = concat(concatenated_data, '", "dataset_code":"');
        concatenated_data = concat(concatenated_data, dataset_code);
        concatenated_data = concat(concatenated_data, '", "selected_band":"');
        concatenated_data = concat(concatenated_data, selected_band);
        concatenated_data = concat(concatenated_data, '", "image_scale":');
        concatenated_data = concat(concatenated_data, image_scale);
        concatenated_data = concat(concatenated_data, ', "start_date":"');
        concatenated_data = concat(concatenated_data, start_date);
        concatenated_data = concat(concatenated_data, '", "end_date":"');
        concatenated_data = concat(concatenated_data, end_date);
        concatenated_data = concat(
            concatenated_data,
            '", "geometry":{"type":"FeatureCollection","features":['
        );

        for (uint256 i = 0; i < geometry.length; i++) {
            geometry_map[geometry[i].property_id] = geometry[i].coordinates;

            concatenated_data = concat(
                concatenated_data,
                '{"type":"Feature","properties":{"id":'
            );
            concatenated_data = concat(
                concatenated_data,
                Strings.toString(geometry[i].property_id)
            );
            concatenated_data = concat(
                concatenated_data,
                '},"geometry":{"type":"Polygon","coordinates":'
            );
            concatenated_data = concat(
                concatenated_data,
                geometry[i].coordinates
            );
            concatenated_data = concat(concatenated_data, "}}");

            if (i != geometry.length - 1) {
                concatenated_data = concat(concatenated_data, ",");
            }
        }
        concatenated_data = concat(concatenated_data, "]}}");
        string memory req_data = concatenated_data;

        req.add("data", req_data);

        sendOperatorRequest(req, 10**18);
    }

    function fulfillGeostatsData(
        bytes32 requestId,
        int256 geostatsData,
        string calldata cidValue
    ) public recordChainlinkFulfillment(requestId) {
        geostats_data = geostatsData;

        cid = cidValue;
        cids[total_oracle_calls] = cid;
        total_oracle_calls = total_oracle_calls + 1;
    }

    function getGeostatsData() public view returns (int256) {
        return geostats_data;
    }

    function getLatestCid() public view returns (string memory) {
        return cid;
    }
}